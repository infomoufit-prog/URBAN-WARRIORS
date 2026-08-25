-- KOMBAX RC13 build 20084 · Security Go-Live + Pilot Readiness
-- Additive hardening. No pilot/security flag is enabled by default.

begin;

create table if not exists public.kombax_security_controls_v149(
  control text primary key,
  category text not null,
  required_for_pilot boolean not null default true,
  status text not null default 'pending' check(status in ('pending','verified','waived','failed')),
  evidence text,
  verified_by uuid references auth.users(id),
  verified_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.kombax_security_controls_v149 enable row level security;
revoke all on table public.kombax_security_controls_v149 from public,anon,authenticated;


create table if not exists public.kombax_security_events_v149(
  id bigint generated always as identity primary key,
  actor_perfil_id uuid,
  auth_session_id text,
  action text not null,
  entity_type text,
  entity_id uuid,
  outcome text not null default 'success',
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_kombax_security_events_v149_actor_action_time on public.kombax_security_events_v149(actor_perfil_id,action,created_at desc);
alter table public.kombax_security_events_v149 enable row level security;
revoke all on table public.kombax_security_events_v149 from public,anon,authenticated;

create table if not exists public.kombax_security_settings_v149(
  singleton boolean primary key default true check(singleton),
  owner_mfa_required boolean not null default false,
  pilot_security_enabled boolean not null default false,
  enabled_by uuid references auth.users(id),
  enabled_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.kombax_security_settings_v149 enable row level security;
revoke all on table public.kombax_security_settings_v149 from public,anon,authenticated;
insert into public.kombax_security_settings_v149(singleton) values(true) on conflict(singleton) do nothing;

-- Owner fail-closed wrapper. Before MFA enforcement the established 30-minute Owner session
-- continues to work. Once enabled, every platform-admin authorization requires an AAL2 JWT.
do $owner_guard$
begin
 if to_regprocedure('public.app_kombax_es_platform_admin_pre_security_149()') is null
    and to_regprocedure('public.app_kombax_es_platform_admin_v055()') is not null then
   alter function public.app_kombax_es_platform_admin_v055() rename to app_kombax_es_platform_admin_pre_security_149;
 end if;
end $owner_guard$;
revoke all on function public.app_kombax_es_platform_admin_pre_security_149() from public,anon,authenticated;
create or replace function public.app_kombax_es_platform_admin_v055()
returns boolean language sql stable security definer set search_path='' as $$
 select public.app_kombax_es_platform_admin_pre_security_149()
   and (
     not coalesce((select s.owner_mfa_required from public.kombax_security_settings_v149 s where s.singleton=true),false)
     or coalesce((select auth.jwt()->>'aal'),'aal1')='aal2'
   );
$$;
revoke all on function public.app_kombax_es_platform_admin_v055() from public,anon;
grant execute on function public.app_kombax_es_platform_admin_v055() to authenticated;

insert into public.kombax_security_controls_v149(control,category,required_for_pilot,status,evidence)
values
 ('context_isolation_20083','authorization',true,'verified','Server-side workspace actor/contact isolation supplied by migration 147.'),
 ('critical_tables_rls','authorization',true,'verified','Critical club/student/finance tables are required to keep RLS enabled.'),
 ('finance_security_invoker_views','finance',true,'verified','Financial views are expected to run as security_invoker.'),
 ('leaked_password_protection','auth',true,'pending',null),
 ('owner_mfa_aal2','auth',true,'pending',null),
 ('backup_restore_drill','resilience',true,'pending',null),
 ('incident_runbook','operations',true,'pending',null),
 ('android_release_security','mobile',true,'pending',null),
 ('two_club_isolation_e2e','authorization',true,'pending',null),
 ('security_advisors_triaged','database',true,'pending',null),
 ('secrets_repository_review','supply_chain',true,'pending',null),
 ('netlify_security_headers','web',true,'pending',null)
on conflict(control) do nothing;

create or replace function private.kombax_security_log_v149(p_action text,p_outcome text default 'success',p_entity_type text default null,p_entity_id uuid default null,p_detail jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path='' as $$
begin
 insert into public.kombax_security_events_v149(actor_perfil_id,auth_session_id,action,entity_type,entity_id,outcome,detail)
 values((select auth.uid()),nullif((select auth.jwt()->>'session_id'),''),left(coalesce(p_action,'unknown'),120),left(p_entity_type,60),p_entity_id,left(coalesce(p_outcome,'unknown'),30),coalesce(p_detail,'{}'::jsonb));
end;$$;
revoke all on function private.kombax_security_log_v149(text,text,text,uuid,jsonb) from public,anon,authenticated;

-- Preserve the existing recent-password gate but require AAL2 before a privileged Owner
-- session can be created after Owner MFA has been turned on.
do $owner_login_guard$
begin
 if to_regprocedure('public.app_kombax_platform_admin_password_session_pre_security_149()') is null
    and to_regprocedure('public.app_kombax_platform_admin_password_session_v139()') is not null then
   alter function public.app_kombax_platform_admin_password_session_v139() rename to app_kombax_platform_admin_password_session_pre_security_149;
 end if;
end $owner_login_guard$;
revoke all on function public.app_kombax_platform_admin_password_session_pre_security_149() from public,anon,authenticated;
create or replace function public.app_kombax_platform_admin_password_session_v139()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_required boolean;
begin
 if v_uid is null or nullif((select auth.jwt()->>'session_id'),'') is null then raise exception 'KOMBAX_ADMIN_AUTH_REQUIRED'; end if;
 if not exists(select 1 from public.kombax_platform_admins a where a.perfil_id=v_uid and a.activo) then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
 if not public.app_kombax_auth_method_recent_v108('password',600) then raise exception 'KOMBAX_ADMIN_PASSWORD_REQUIRED'; end if;
 select owner_mfa_required into v_required from public.kombax_security_settings_v149 where singleton=true;
 if coalesce(v_required,false) and coalesce((select auth.jwt()->>'aal'),'aal1')<>'aal2' then
   perform private.kombax_security_log_v149('owner.admin.session.start','blocked','platform',v_uid,jsonb_build_object('reason','aal2_required'));
   raise exception 'OWNER_AAL2_REQUIRED';
 end if;
 return public.app_kombax_platform_admin_password_session_pre_security_149();
end;$$;
revoke all on function public.app_kombax_platform_admin_password_session_v139() from public,anon;
grant execute on function public.app_kombax_platform_admin_password_session_v139() to authenticated;

create or replace function private.kombax_security_owner_v149()
returns boolean language sql stable security definer set search_path='' as $$
 select (select auth.uid()) is not null and public.app_kombax_es_platform_admin_v055();
$$;
revoke all on function private.kombax_security_owner_v149() from public,anon,authenticated;

create or replace function private.kombax_security_owner_aal2_v149()
returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select auth.jwt()->>'aal'),'aal1')='aal2';
$$;
revoke all on function private.kombax_security_owner_aal2_v149() from public,anon,authenticated;

create or replace function private.kombax_security_rate_ok_v149(p_action text,p_limit int,p_window interval)
returns boolean language sql stable security definer set search_path='' as $$
 select count(*) < greatest(1,p_limit)
 from public.kombax_security_events_v149 e
 where e.actor_perfil_id=(select auth.uid()) and e.action=p_action and e.created_at>now()-p_window;
$$;
revoke all on function private.kombax_security_rate_ok_v149(text,int,interval) from public,anon,authenticated;

create or replace function public.app_kombax_security_status_v149()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_required int;v_verified int;v_failed int;v_controls jsonb;v_settings public.kombax_security_settings_v149;v_rls_ok boolean;v_fin_views_ok boolean;
begin
 if not private.kombax_security_owner_v149() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
 select * into v_settings from public.kombax_security_settings_v149 where singleton=true;
 select count(*) filter(where required_for_pilot),count(*) filter(where required_for_pilot and status='verified'),count(*) filter(where required_for_pilot and status='failed')
 into v_required,v_verified,v_failed from public.kombax_security_controls_v149;
 select coalesce(jsonb_agg(to_jsonb(c) order by c.category,c.control),'[]'::jsonb) into v_controls from public.kombax_security_controls_v149 c;
 select count(*)=13 into v_rls_ok from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname=any(array['socios','socio_disciplinas','grupos','disciplinas','cuotas','pagos','recibos_cuota','documentos_socios','sesiones_entrenamiento','asistencias','notificaciones','miembros_club','config_club']) and c.relrowsecurity;
 select count(*)=4 into v_fin_views_ok from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname=any(array['v_estado_cuenta_socio','v_finanzas_detalle','v_finanzas_metricas_anuales','v_finanzas_metricas_mensuales']) and 'security_invoker=true'=any(coalesce(c.reloptions,array[]::text[]));
 return jsonb_build_object('pilot_ready',v_required=v_verified and v_failed=0 and v_rls_ok and v_fin_views_ok and coalesce(v_settings.owner_mfa_required,false),
   'pilot_enabled',coalesce(v_settings.pilot_security_enabled,false),'owner_mfa_required',coalesce(v_settings.owner_mfa_required,false),'current_aal',coalesce((select auth.jwt()->>'aal'),'aal1'),
   'required',v_required,'verified',v_verified,'failed',v_failed,'critical_rls_ok',v_rls_ok,'finance_security_invoker_ok',v_fin_views_ok,'controls',v_controls);
end;$$;
revoke all on function public.app_kombax_security_status_v149() from public,anon;
grant execute on function public.app_kombax_security_status_v149() to authenticated;

create or replace function public.app_kombax_security_control_attest_v149(p_control text,p_status text,p_evidence text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_status text:=lower(btrim(coalesce(p_status,'')));v_control text:=lower(btrim(coalesce(p_control,'')));
begin
 if not private.kombax_security_owner_v149() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
 if not private.kombax_security_owner_aal2_v149() then raise exception 'OWNER_AAL2_REQUIRED'; end if;
 if v_status not in ('verified','failed','pending') then raise exception 'SECURITY_CONTROL_STATUS_INVALID'; end if;
 if char_length(btrim(coalesce(p_evidence,'')))<8 then raise exception 'SECURITY_CONTROL_EVIDENCE_REQUIRED'; end if;
 update public.kombax_security_controls_v149 set status=v_status,evidence=left(p_evidence,2000),verified_by=(select auth.uid()),verified_at=case when v_status='verified' then now() else null end,updated_at=now() where control=v_control;
 if not found then raise exception 'SECURITY_CONTROL_NOT_FOUND'; end if;
 perform private.kombax_security_log_v149('security.control.attest','success','security_control',null,jsonb_build_object('control',v_control,'status',v_status));
 return public.app_kombax_security_status_v149();
end;$$;
revoke all on function public.app_kombax_security_control_attest_v149(text,text,text) from public,anon;
grant execute on function public.app_kombax_security_control_attest_v149(text,text,text) to authenticated;

create or replace function public.app_kombax_security_owner_mfa_enforce_v149(p_confirmacion text)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.kombax_security_owner_v149() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
 if not private.kombax_security_owner_aal2_v149() then raise exception 'OWNER_AAL2_REQUIRED'; end if;
 if upper(btrim(coalesce(p_confirmacion,'')))<>'EXIGIR MFA OWNER' then raise exception 'OWNER_MFA_CONFIRMATION_REQUIRED'; end if;
 update public.kombax_security_settings_v149 set owner_mfa_required=true,updated_at=now() where singleton=true;
 update public.kombax_security_controls_v149 set status='verified',evidence='AAL2 verified in authenticated Owner session and enforcement enabled.',verified_by=(select auth.uid()),verified_at=now(),updated_at=now() where control='owner_mfa_aal2';
 perform private.kombax_security_log_v149('security.owner_mfa.enforce','success');
 return public.app_kombax_security_status_v149();
end;$$;
revoke all on function public.app_kombax_security_owner_mfa_enforce_v149(text) from public,anon;
grant execute on function public.app_kombax_security_owner_mfa_enforce_v149(text) to authenticated;

create or replace function public.app_kombax_platform_entity_session_start_v149(p_entidad_tipo text,p_entidad_id uuid,p_motivo text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_mfa boolean;v_result jsonb;
begin
 if not private.kombax_security_owner_v149() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
 select owner_mfa_required into v_mfa from public.kombax_security_settings_v149 where singleton=true;
 if coalesce(v_mfa,false) and not private.kombax_security_owner_aal2_v149() then
   perform private.kombax_security_log_v149('owner.support.session.start','blocked','entity',p_entidad_id,jsonb_build_object('reason','aal2_required'));
   raise exception 'OWNER_AAL2_REQUIRED';
 end if;
 if not private.kombax_security_rate_ok_v149('owner.support.session.start',10,interval '10 minutes') then
   perform private.kombax_security_log_v149('owner.support.session.start','blocked','entity',p_entidad_id,jsonb_build_object('reason','rate_limit'));
   raise exception 'OWNER_SUPPORT_RATE_LIMITED';
 end if;
 v_result:=public.app_kombax_platform_entity_session_start_v114(p_entidad_tipo,p_entidad_id,p_motivo);
 perform private.kombax_security_log_v149('owner.support.session.start','success',lower(btrim(p_entidad_tipo)),p_entidad_id,jsonb_build_object('entity_session_id',v_result->>'entity_session_id'));
 return v_result;
end;$$;
revoke all on function public.app_kombax_platform_entity_session_start_v149(text,uuid,text) from public,anon;
grant execute on function public.app_kombax_platform_entity_session_start_v149(text,uuid,text) to authenticated;
-- Remove the bypass path once the 20.084 client is deployed. v149 calls v114 as function owner.
revoke execute on function public.app_kombax_platform_entity_session_start_v114(text,uuid,text) from authenticated;

create or replace function public.app_kombax_security_surface_v149()
returns table(function_name text,identity_args text,anon_exec boolean,authenticated_exec boolean,classification text)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.kombax_security_owner_v149() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
 return query
 select p.proname::text,pg_get_function_identity_arguments(p.oid),has_function_privilege('anon',p.oid,'EXECUTE'),has_function_privilege('authenticated',p.oid,'EXECUTE'),
 case when has_function_privilege('anon',p.oid,'EXECUTE') then 'public_review'
      when has_function_privilege('authenticated',p.oid,'EXECUTE') then 'authenticated_review'
      else 'internal' end
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.prosecdef
 order by 5,1,2;
end;$$;
revoke all on function public.app_kombax_security_surface_v149() from public,anon;
grant execute on function public.app_kombax_security_surface_v149() to authenticated;

create or replace function public.app_kombax_security_pilot_enable_v149(p_confirmacion text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_status jsonb;
begin
 if not private.kombax_security_owner_v149() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
 if not private.kombax_security_owner_aal2_v149() then raise exception 'OWNER_AAL2_REQUIRED'; end if;
 if upper(btrim(coalesce(p_confirmacion,'')))<>'HABILITAR PILOTO KOMBAX' then raise exception 'SECURITY_PILOT_CONFIRMATION_REQUIRED'; end if;
 v_status:=public.app_kombax_security_status_v149();
 if coalesce((v_status->>'pilot_ready')::boolean,false) is not true then raise exception 'SECURITY_PILOT_NOT_READY'; end if;
 update public.kombax_security_settings_v149 set pilot_security_enabled=true,enabled_by=(select auth.uid()),enabled_at=now(),updated_at=now() where singleton=true;
 perform private.kombax_security_log_v149('security.pilot.enable','success');
 return public.app_kombax_security_status_v149();
end;$$;
revoke all on function public.app_kombax_security_pilot_enable_v149(text) from public,anon;
grant execute on function public.app_kombax_security_pilot_enable_v149(text) to authenticated;

-- Final finance defense: real recurring execution cannot run before the global security pilot gate is enabled.
do $wrap$
begin
 if to_regprocedure('public.procesar_cargos_recurrentes_pre_security_149(date,uuid,boolean,boolean)') is null then
   alter function public.procesar_cargos_recurrentes(date,uuid,boolean,boolean) rename to procesar_cargos_recurrentes_pre_security_149;
 end if;
end $wrap$;
revoke all on function public.procesar_cargos_recurrentes_pre_security_149(date,uuid,boolean,boolean) from public,anon,authenticated;
grant execute on function public.procesar_cargos_recurrentes_pre_security_149(date,uuid,boolean,boolean) to service_role;
create or replace function public.procesar_cargos_recurrentes(p_fecha date default current_date,p_club_id uuid default null,p_shadow boolean default true,p_forzar_ciclo_actual boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_enabled boolean;
begin
 if not p_shadow then
   select pilot_security_enabled into v_enabled from public.kombax_security_settings_v149 where singleton=true;
   if not coalesce(v_enabled,false) then return jsonb_build_object('ok',true,'disabled',true,'reason','security_pilot_enabled=false','club_id',p_club_id); end if;
 end if;
 return public.procesar_cargos_recurrentes_pre_security_149(p_fecha,p_club_id,p_shadow,p_forzar_ciclo_actual);
end;$$;
revoke all on function public.procesar_cargos_recurrentes(date,uuid,boolean,boolean) from public,anon;
grant execute on function public.procesar_cargos_recurrentes(date,uuid,boolean,boolean) to authenticated,service_role;

-- Block finance live activation from the general gateway until Security Go-Live is enabled.
do $gateway$
begin
 if to_regprocedure('public.app_mutate_v160_pre_security_149(text,jsonb,uuid)') is null then
   alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_security_149;
 end if;
end $gateway$;
revoke all on function public.app_mutate_v160_pre_security_149(text,jsonb,uuid) from public,anon,authenticated;
create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_enabled boolean;
begin
 if p_operation='finance.pilot.activar' then
   select pilot_security_enabled into v_enabled from public.kombax_security_settings_v149 where singleton=true;
   if not coalesce(v_enabled,false) then raise exception 'SECURITY_PILOT_REQUIRED'; end if;
 end if;
 return public.app_mutate_v160_pre_security_149(p_operation,p_payload,p_request_id);
end;$$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

commit;
