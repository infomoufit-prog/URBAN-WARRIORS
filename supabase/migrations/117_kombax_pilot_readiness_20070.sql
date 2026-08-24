-- KOMBAX RC13 build 20070 · preparación controlada para pilotos con clubes reales.
-- No activa servicios de pago ni cambia usuarios, clubes, roles Owner o datos existentes.
begin;

-- Separación de funciones: moderación de contenido y verificación documental son roles distintos.
create table if not exists public.kombax_verificadores_globales_v117(
  perfil_id uuid primary key references public.perfiles(id) on delete cascade,
  activo boolean not null default true,
  asignado_por uuid not null references public.perfiles(id) on delete restrict,
  motivo text not null check(char_length(btrim(motivo)) between 10 and 500),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);
alter table public.kombax_verificadores_globales_v117 enable row level security;
revoke all on public.kombax_verificadores_globales_v117 from public,anon,authenticated;

create or replace function public.app_kombax_es_verificador_v117()
returns boolean language sql stable security definer set search_path=public,auth as $$
  select auth.uid() is not null and (
    public.app_kombax_es_platform_admin_v055()
    or exists(select 1 from public.kombax_verificadores_globales_v117 v where v.perfil_id=auth.uid() and v.activo)
  );
$$;
revoke all on function public.app_kombax_es_verificador_v117() from public,anon;
grant execute on function public.app_kombax_es_verificador_v117() to authenticated;

drop policy if exists kombax_verification_docs_select_v043 on storage.objects;
create policy kombax_verification_docs_select_v117 on storage.objects for select to authenticated using(
  bucket_id='kombax-verification-docs'
  and ((storage.foldername(name))[1]=auth.uid()::text or public.app_kombax_es_verificador_v117())
);
drop policy if exists kombax_verification_docs_delete_v043 on storage.objects;
create policy kombax_verification_docs_delete_v117 on storage.objects for delete to authenticated using(
  bucket_id='kombax-verification-docs'
  and ((storage.foldername(name))[1]=auth.uid()::text or public.app_kombax_es_verificador_v117())
);

create or replace function public.app_kombax_verificador_set_v117(p_perfil_id uuid,p_activo boolean,p_motivo text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_reason text:=btrim(coalesce(p_motivo,''));
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  if p_perfil_id is null or not exists(select 1 from public.perfiles where id=p_perfil_id) then raise exception 'KOMBAX_VERIFIER_ACCOUNT_NOT_FOUND';end if;
  if char_length(v_reason)<10 then raise exception 'KOMBAX_AUDIT_REASON_REQUIRED';end if;
  insert into public.kombax_verificadores_globales_v117(perfil_id,activo,asignado_por,motivo)
  values(p_perfil_id,coalesce(p_activo,false),v_uid,v_reason)
  on conflict(perfil_id) do update set activo=excluded.activo,asignado_por=excluded.asignado_por,motivo=excluded.motivo,actualizado_en=now();
  insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle)
  values(v_uid,null,'kombax.platform.verifier.set','platform_verifier',p_perfil_id,jsonb_build_object('activo',coalesce(p_activo,false),'motivo',v_reason));
  return jsonb_build_object('ok',true,'perfil_id',p_perfil_id,'activo',coalesce(p_activo,false));
end $$;
revoke all on function public.app_kombax_verificador_set_v117(uuid,boolean,text) from public,anon;
grant execute on function public.app_kombax_verificador_set_v117(uuid,boolean,text) to authenticated;

-- Perfil administrativo con ID de cuenta canónico; evita asignar roles a IDs de perfil público.
create or replace function public.app_kombax_platform_profiles_v117(p_query text default '',p_limit integer default 100)
returns table(id uuid,actor_perfil_id uuid,nombre_publico text,tipo text,estado text,verificado boolean,badge_type text,club_id uuid,club_nombre text,servicio_estado text,plan_codigo text,es_moderador boolean,es_verificador boolean,actualizado_en timestamptz)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_query text:=lower(btrim(coalesce(p_query,'')));
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  return query
  select sp.id,coalesce(i.perfil_id,d.perfil_id),sp.nombre_publico,public.app_kombax_social_tipo_v051(sp.id),sp.estado,sp.verificado,
    public.app_kombax_badge_tipo_v069(sp.id),sp.club_id,c.nombre,coalesce(s.estado,'inactiva'),s.modalidad,
    coalesce(m.activo,false),coalesce(v.activo,false),sp.actualizado_en
  from public.kombax_social_perfiles sp
  left join public.clubes c on c.id=sp.club_id
  left join public.identidades_sociales i on i.id=sp.identidad_social_id
  left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  left join public.kombax_moderadores_globales m on m.perfil_id=coalesce(i.perfil_id,d.perfil_id)
  left join public.kombax_verificadores_globales_v117 v on v.perfil_id=coalesce(i.perfil_id,d.perfil_id)
  left join lateral(select x.estado,x.modalidad from public.kombax_suscripciones x where x.sujeto_tipo='perfil_directo' and x.sujeto_id=d.id order by x.actualizado_en desc limit 1)s on true
  where v_query='' or lower(coalesce(sp.nombre_publico,'')||' '||coalesce(c.nombre,'')||' '||coalesce(sp.slug,'')) like '%'||v_query||'%'
  order by sp.actualizado_en desc limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_platform_profiles_v117(text,integer) from public,anon;
grant execute on function public.app_kombax_platform_profiles_v117(text,integer) to authenticated;

-- Atestaciones manuales: nunca se marcan automáticamente ni se inventan valores jurídicos.
create table if not exists public.kombax_pilot_readiness_v117(
  control text primary key check(control in ('smtp','legal_controller','owner_mfa','backup_export','restore_drill','monitoring','incident_runbook')),
  verificado boolean not null default false,
  evidencia text check(char_length(coalesce(evidencia,''))<=1000),
  verificado_por uuid references public.perfiles(id) on delete set null,
  verificado_en timestamptz,
  actualizado_en timestamptz not null default now(),
  check(not verificado or (char_length(btrim(coalesce(evidencia,'')))>=10 and verificado_por is not null and verificado_en is not null))
);
alter table public.kombax_pilot_readiness_v117 enable row level security;
revoke all on public.kombax_pilot_readiness_v117 from public,anon,authenticated;
insert into public.kombax_pilot_readiness_v117(control) values
 ('smtp'),('legal_controller'),('owner_mfa'),('backup_export'),('restore_drill'),('monitoring'),('incident_runbook')
on conflict(control) do nothing;

create or replace function public.app_kombax_pilot_readiness_status_v117()
returns jsonb language plpgsql stable security definer set search_path=public,auth,storage as $$
declare v_manual jsonb;v_ready boolean;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  select coalesce(jsonb_object_agg(control,jsonb_build_object('verified',verificado,'evidence',evidencia,'verified_at',verificado_en)),'{}'::jsonb),bool_and(verificado)
    into v_manual,v_ready from public.kombax_pilot_readiness_v117;
  return jsonb_build_object(
    'build',20070,'pilot_ready',coalesce(v_ready,false),
    'manual',v_manual,
    'technical',jsonb_build_object(
      'rls_verifiers',to_regclass('public.kombax_verificadores_globales_v117') is not null,
      'private_docs_policy',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='kombax_verification_docs_select_v117'),
      'owner_password_only',to_regprocedure('public.app_kombax_platform_admin_password_complete_v110(uuid)') is not null,
      'incident_capture',to_regprocedure('public.app_kombax_client_incident_report_v117(text,text,text,jsonb)') is not null
    )
  );
end $$;
revoke all on function public.app_kombax_pilot_readiness_status_v117() from public,anon;
grant execute on function public.app_kombax_pilot_readiness_status_v117() to authenticated;

create or replace function public.app_kombax_pilot_readiness_set_v117(p_control text,p_verificado boolean,p_evidencia text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_control text:=lower(btrim(coalesce(p_control,'')));v_evidence text:=left(btrim(coalesce(p_evidencia,'')),1000);
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  if v_control not in ('smtp','legal_controller','owner_mfa','backup_export','restore_drill','monitoring','incident_runbook') then raise exception 'KOMBAX_READINESS_CONTROL_INVALID';end if;
  if coalesce(p_verificado,false) and char_length(v_evidence)<10 then raise exception 'KOMBAX_READINESS_EVIDENCE_REQUIRED';end if;
  update public.kombax_pilot_readiness_v117 set verificado=coalesce(p_verificado,false),evidencia=nullif(v_evidence,''),
    verificado_por=case when p_verificado then v_uid else null end,verificado_en=case when p_verificado then now() else null end,actualizado_en=now()
    where control=v_control;
  insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle)
  values(v_uid,null,'kombax.platform.pilot_readiness.set','pilot_readiness',v_uid,jsonb_build_object('control',v_control,'verified',coalesce(p_verificado,false),'evidence',nullif(v_evidence,'')));
  return jsonb_build_object('ok',true,'control',v_control,'verified',coalesce(p_verificado,false));
end $$;
revoke all on function public.app_kombax_pilot_readiness_set_v117(text,boolean,text) from public,anon;
grant execute on function public.app_kombax_pilot_readiness_set_v117(text,boolean,text) to authenticated;

-- Telemetría propia y mínima: sin tokens, contraseñas, cuerpos de mensajes ni datos legales.
create table if not exists public.kombax_client_incidents_v117(
  id bigint generated always as identity primary key,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  build text not null check(char_length(build) between 1 and 20),
  codigo text not null check(codigo ~ '^[A-Z0-9_.-]{3,80}$'),
  mensaje text not null check(char_length(mensaje) between 1 and 500),
  contexto jsonb not null default '{}'::jsonb,
  creado_en timestamptz not null default now(),
  resuelto_en timestamptz,
  check(jsonb_typeof(contexto)='object')
);
create index if not exists idx_kombax_client_incidents_v117 on public.kombax_client_incidents_v117(creado_en desc);
alter table public.kombax_client_incidents_v117 enable row level security;
revoke all on public.kombax_client_incidents_v117 from public,anon,authenticated;

create or replace function public.app_kombax_client_incident_report_v117(p_build text,p_codigo text,p_mensaje text,p_contexto jsonb default '{}'::jsonb)
returns bigint language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_id bigint;v_code text:=upper(btrim(coalesce(p_codigo,'')));v_message text:=left(btrim(coalesce(p_mensaje,'')),500);v_context jsonb:=coalesce(p_contexto,'{}'::jsonb);
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if v_code!~'^[A-Z0-9_.-]{3,80}$' or v_message='' or jsonb_typeof(v_context)<>'object' then raise exception 'KOMBAX_INCIDENT_INVALID';end if;
  if exists(select 1 from public.kombax_client_incidents_v117 where perfil_id=v_uid and creado_en>now()-interval '1 hour' offset 19) then raise exception 'KOMBAX_INCIDENT_RATE_LIMIT';end if;
  v_context:=v_context-'access_token'-'refresh_token'-'password'-'email'-'telefono'-'phone'-'documento'-'message_body';
  insert into public.kombax_client_incidents_v117(perfil_id,build,codigo,mensaje,contexto)
  values(v_uid,left(coalesce(nullif(btrim(p_build),''),'unknown'),20),v_code,v_message,v_context) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.app_kombax_client_incident_report_v117(text,text,text,jsonb) from public,anon;
grant execute on function public.app_kombax_client_incident_report_v117(text,text,text,jsonb) to authenticated;

create or replace function public.app_kombax_client_incidents_v117(p_limit integer default 100)
returns table(id bigint,perfil_id uuid,build text,codigo text,mensaje text,contexto jsonb,creado_en timestamptz,resuelto_en timestamptz)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  return query select x.id,x.perfil_id,x.build,x.codigo,x.mensaje,x.contexto,x.creado_en,x.resuelto_en
  from public.kombax_client_incidents_v117 x order by x.creado_en desc limit least(greatest(coalesce(p_limit,100),1),500);
end $$;
revoke all on function public.app_kombax_client_incidents_v117(integer) from public,anon;
grant execute on function public.app_kombax_client_incidents_v117(integer) to authenticated;

notify pgrst,'reload schema';
commit;
