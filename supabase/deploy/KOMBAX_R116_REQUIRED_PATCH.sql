-- KOMBAX R116 Golden Pilot Freeze · explicit required database delta
-- Apply ONLY after running KOMBAX_R116_SUPABASE_PREFLIGHT.sql.
-- Do NOT replace this with `supabase db push`: this repository preserves a mixed
-- historical migration archive whose local numeric versions do not mirror the
-- production migration-history timestamps.
-- Both included migrations are additive/idempotent for the objects they own.

-- SOURCE: supabase/migrations/300_kombax_owner_command_center_r114.sql
-- KOMBAX R114 · Owner Command Center / global Owner alerts / report payload.
-- Additive only. No commercial, identity or RLS rules are relaxed.
begin;

create unique index if not exists uq_notificaciones_global_perfil_clave_r114
  on public.notificaciones(perfil_id,clave)
  where club_id is null and perfil_id is not null and clave is not null;

create or replace function public.app_kombax_owner_alerts_r114(p_limit integer default 80)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_limit int:=least(greatest(coalesce(p_limit,80),1),200);v_items jsonb;v_counts jsonb;
begin
  if v_uid is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.creado_en desc),'[]'::jsonb) into v_items from (
    select n.id,n.tipo,n.titulo,n.cuerpo,n.ruta,n.datos,n.leida,n.creado_en,n.subject_type,n.subject_id,n.push_enviado_en,n.push_intentos,n.push_error
    from public.notificaciones n where n.perfil_id=v_uid and n.club_id is null
    order by n.creado_en desc limit v_limit
  ) x;
  select jsonb_build_object(
    'unread',count(*) filter(where not n.leida),
    'action_required',count(*) filter(where not n.leida and coalesce((n.datos->>'requiere_accion')::boolean,false)),
    'critical',count(*) filter(where not n.leida and n.datos->>'priority'='critical'),
    'warning',count(*) filter(where not n.leida and n.datos->>'priority'='warning'),
    'push_pending',count(*) filter(where not n.leida and n.push_enviado_en is null and coalesce(n.push_intentos,0)<3)
  ) into v_counts from public.notificaciones n where n.perfil_id=v_uid and n.club_id is null;
  return jsonb_build_object('ok',true,'items',v_items,'counts',coalesce(v_counts,'{}'::jsonb));
end $$;
revoke all on function public.app_kombax_owner_alerts_r114(integer) from public,anon;
grant execute on function public.app_kombax_owner_alerts_r114(integer) to authenticated;

create or replace function public.app_kombax_owner_report_payload_r114(p_days integer default 90)
returns jsonb language plpgsql stable security definer set search_path=public,auth,kombax_owner_ai as $$
declare v_days int:=least(greatest(coalesce(p_days,90),7),365);v_metrics jsonb;v_alerts jsonb;v_agents jsonb;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  v_metrics:=public.app_kombax_metrics_platform_v133(v_days);
  select jsonb_build_object(
    'total',count(*),
    'completed',count(*) filter(where status='completed'),
    'failed',count(*) filter(where status='failed'),
    'high_risk',count(*) filter(where risk_level in ('high','critical')),
    'operations',count(*) filter(where agent='owner_operations'),
    'pilot_intelligence',count(*) filter(where agent='pilot_intelligence')
  ) into v_agents from kombax_owner_ai.agent_turns where created_at>=now()-(v_days||' days')::interval;
  select jsonb_build_object(
    'unread',count(*) filter(where not leida),
    'action_required',count(*) filter(where not leida and coalesce((datos->>'requiere_accion')::boolean,false)),
    'critical',count(*) filter(where not leida and datos->>'priority'='critical'),
    'warnings',count(*) filter(where not leida and datos->>'priority'='warning')
  ) into v_alerts from public.notificaciones where perfil_id=auth.uid() and club_id is null;
  return jsonb_build_object('ok',true,'days',v_days,'generated_at',now(),'metrics',v_metrics,'owner_alerts',coalesce(v_alerts,'{}'::jsonb),'agents',coalesce(v_agents,'{}'::jsonb));
end $$;
revoke all on function public.app_kombax_owner_report_payload_r114(integer) from public,anon;
grant execute on function public.app_kombax_owner_report_payload_r114(integer) to authenticated;

create or replace function public.app_kombax_owner_notify_verification_r114()
returns trigger language plpgsql security definer set search_path=public,auth as $$
begin
  if new.estado='submitted' and (tg_op='INSERT' or old.estado is distinct from new.estado) then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,subject_type,subject_id)
    select null,a.perfil_id,'owner:verification:'||new.id::text||':submitted','owner_action',
      'Nueva verificación pendiente','Hay una nueva solicitud de verificación pendiente de revisión.','platform-admin',
      jsonb_build_object('priority','action_required','requiere_accion',true,'owner_section','owner-verifications','application_type',new.tipo),
      'verification',new.id
    from public.kombax_platform_admins a where a.activo
    on conflict do nothing;
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_owner_notify_verification_r114() from public,anon,authenticated;

drop trigger if exists trg_kombax_owner_notify_verification_r114 on public.kombax_solicitudes_alta;
create trigger trg_kombax_owner_notify_verification_r114
after insert or update of estado on public.kombax_solicitudes_alta
for each row execute function public.app_kombax_owner_notify_verification_r114();

create or replace function public.app_kombax_owner_notify_agent_r114()
returns trigger language plpgsql security definer set search_path=public,auth,kombax_owner_ai as $$
declare v_priority text;v_required boolean;
begin
  if old.status is not distinct from new.status and old.risk_level is not distinct from new.risk_level then return new; end if;
  if new.status='failed' or (new.status='completed' and new.risk_level in ('high','critical')) then
    v_priority:=case when new.risk_level='critical' then 'critical' when new.status='failed' or new.risk_level='high' then 'warning' else 'info' end;
    v_required:=new.status='failed' or new.risk_level in ('high','critical');
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,subject_type,subject_id)
    values(null,new.requested_by,'owner:agent:'||new.id::text||':'||new.status||':'||coalesce(new.risk_level,'none'),'owner_agent',
      case when new.status='failed' then 'Agente Owner requiere atención' else 'Agente Owner detectó un riesgo' end,
      case when new.status='failed' then 'Una ejecución de agente no pudo completarse. Revisa la trazabilidad en Owner.' else 'Un agente ha marcado un resultado de riesgo alto. Revisa su recomendación antes de actuar.' end,
      'platform-admin',jsonb_build_object('priority',v_priority,'requiere_accion',v_required,'owner_section','owner-agents','agent',new.agent,'status',new.status,'risk_level',new.risk_level),
      'owner_agent_turn',new.id)
    on conflict do nothing;
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_owner_notify_agent_r114() from public,anon,authenticated;

drop trigger if exists trg_kombax_owner_notify_agent_r114 on kombax_owner_ai.agent_turns;
create trigger trg_kombax_owner_notify_agent_r114
after update of status,risk_level on kombax_owner_ai.agent_turns
for each row execute function public.app_kombax_owner_notify_agent_r114();

notify pgrst,'reload schema';
commit;

-- SOURCE: supabase/migrations/301_kombax_pilot_onboarding_member_social_gate_r115.sql
-- KOMBAX R115 · Pilot freeze onboarding / membership authority / Social gate
-- Principle: a free account is not automatically Spectator and self-declaring as
-- Member/Practitioner never grants Social publishing. The club-confirmed active
-- membership remains the authority. Competitor stays autonomous after verification.

begin;

create or replace function public.app_kombax_member_membership_confirmed_r115(p_club_id uuid default null)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1
    from public.socios s
    join public.miembros_club mc
      on mc.club_id=s.club_id
     and mc.perfil_id=auth.uid()
     and mc.rol='alumno'
     and mc.activo
    where s.perfil_id=auth.uid()
      and s.estado='activo'
      and s.kombax_acceso_estado='activo'
      and (p_club_id is null or s.club_id=p_club_id)
  );
$$;
revoke all on function public.app_kombax_member_membership_confirmed_r115(uuid) from public,anon;
grant execute on function public.app_kombax_member_membership_confirmed_r115(uuid) to authenticated;

-- Harden the canonical publication/action gate without altering the direct-profile
-- rules introduced in R109. Member publication requires an active identity AND an
-- active club-approved membership represented in socios + miembros_club.
create or replace function public.app_kombax_social_puede_actuar_v051(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and sp.publicar_habilitado and (
      (sp.sujeto_tipo='miembro' and exists(
        select 1
        from public.identidades_sociales i
        join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
        join public.miembros_club mc on mc.club_id=s.club_id and mc.perfil_id=auth.uid() and mc.rol='alumno' and mc.activo
        where i.id=sp.identidad_social_id
          and i.perfil_id=auth.uid()
          and i.estado='activa'
          and s.perfil_id=auth.uid()
          and s.estado='activo'
          and s.kombax_acceso_estado='activo'
          and s.fecha_nacimiento is not null
          and extract(year from age(current_date,s.fecha_nacimiento))>=14
      ))
      or (sp.sujeto_tipo='club'
        and public.app_kombax_club_permiso_v051(sp.club_id,'social.publish')
        and public.app_kombax_club_permiso_v051(sp.club_id,'social.act_as_club'))
      or (sp.sujeto_tipo='perfil_directo' and exists(
        select 1 from public.perfiles_kombax_directos d
        where d.id=sp.perfil_directo_id and d.perfil_id=auth.uid()
          and d.estado='activo' and d.verificacion_estado='verificado' and d.social_activo
          and (
            d.tipo in ('marca','federacion','media')
            or (d.tipo='competidor' and d.fecha_nacimiento_verificada is not null
                and d.fecha_nacimiento_verificada<=current_date-interval '16 years')
            or (d.tipo='profesional' and exists(
              select 1 from public.kombax_perfil_persona_privada_v196 p
              where p.perfil_directo_id=d.id and public.app_kombax_profile_age_v196(p.fecha_nacimiento)>=18
            ))
          )
      ))
    )
  );
$$;
revoke all on function public.app_kombax_social_puede_actuar_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_actuar_v051(uuid) to authenticated;

create or replace function public.app_kombax_social_puede_publicar_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_social_puede_actuar_v051(p_social_id);
$$;
revoke all on function public.app_kombax_social_puede_publicar_v041(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_publicar_v041(uuid) to authenticated;

-- Latest read status. Preserve every R123 minor-safety decision, then make the
-- membership authority explicit so the UI cannot advertise member activation after
-- the club relationship has been suspended/revoked.
create or replace function public.app_kombax_social_estado_v124(p_club_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;v_uid uuid:=auth.uid();
begin
  v:=public.app_kombax_social_estado_v123(p_club_id);
  if v_uid is null then return v; end if;
  if coalesce(v->>'scope','')='member' and not public.app_kombax_member_membership_confirmed_r115(p_club_id) then
    return v||jsonb_build_object(
      'status','inactiva','eligible',false,'membership_confirmed',false,
      'reason','Tu club debe confirmar una membresía activa antes de que puedas publicar en KOMBAX Social como Miembro/Practicante.'
    );
  end if;
  if coalesce(v->>'scope','')='member' then v:=v||jsonb_build_object('membership_confirmed',true); end if;
  return v;
end $$;
revoke all on function public.app_kombax_social_estado_v124(uuid) from public,anon;
grant execute on function public.app_kombax_social_estado_v124(uuid) to authenticated;

-- Latest mutation wrapper: activation/profile changes for the member identity are
-- impossible unless the club-approved membership is still active. Other identities
-- preserve R123/R109 behavior, including standalone Competitor verification.
create or replace function public.app_kombax_identity_mutate_v124(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_club uuid;
begin
  if p_operation in ('kombax.identity.member.activate','kombax.identity.member.profile.update') then
    begin v_club:=nullif(p_payload->>'club_id','')::uuid; exception when others then v_club:=null; end;
    if not public.app_kombax_member_membership_confirmed_r115(v_club) then
      raise exception 'KOMBAX_MEMBER_CLUB_CONFIRMATION_REQUIRED';
    end if;
  end if;
  return public.app_kombax_identity_mutate_v123(p_operation,p_payload,p_request_id);
end $$;
revoke all on function public.app_kombax_identity_mutate_v124(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_identity_mutate_v124(text,jsonb,uuid) to authenticated;

commit;
