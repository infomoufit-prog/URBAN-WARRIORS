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
