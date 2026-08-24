begin;

-- ---------------------------------------------------------------------------
-- Retention purge: aggregate first, then remove low-value raw history.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_retention_purge_v133()
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare p public.kombax_retention_policy_v133%rowtype;v_notifs int:=0;v_invites int:=0;v_challenges int:=0;v_sessions int:=0;v_contacts int:=0;v_pre int:=0;v_sports int:=0;
begin
  select * into p from public.kombax_retention_policy_v133 where singleton;
  -- Metrics for today/yesterday are refreshed before any purge. Historical metrics are immutable enough for sales/consumption trends.
  perform public.app_kombax_metrics_collect_date_v133(current_date-1);
  perform public.app_kombax_metrics_collect_date_v133(current_date);

  delete from public.kombax_platform_admin_sessions where coalesce(terminado_en,expira_en) < now()-make_interval(days=>p.admin_sessions_days);
  get diagnostics v_sessions=row_count;
  delete from public.kombax_platform_admin_challenges where coalesce(consumido_en,expira_en) < now()-make_interval(days=>p.admin_challenges_days);
  get diagnostics v_challenges=row_count;
  delete from public.invitaciones_club where (expira_en < now()-make_interval(days=>p.invitation_history_days)) or (estado<>'pendiente' and creado_en < now()-make_interval(days=>p.invitation_history_days));
  get diagnostics v_invites=row_count;
  delete from public.preinscripciones where estado in ('rechazada','cancelada') and creado_en < now()-make_interval(days=>p.rejected_preinscriptions_days);
  get diagnostics v_pre=row_count;
  delete from public.kombax_social_contactos c where c.eliminado_remitente_en is not null and c.eliminado_destinatario_en is not null
    and greatest(c.eliminado_remitente_en,c.eliminado_destinatario_en) < now()-make_interval(days=>p.deleted_conversations_days)
    and not exists(select 1 from public.kombax_message_report_evidence_v122 e where e.contacto_id=c.id)
    and not exists(select 1 from public.kombax_social_reportes r where r.objetivo_tipo in ('contacto','mensaje') and (r.objetivo_id=c.id or r.objetivo_id in (select id from public.kombax_social_contacto_mensajes where contacto_id=c.id)));
  get diagnostics v_contacts=row_count;
  delete from public.notificaciones n where n.creado_en < now()-make_interval(days=>p.notifications_keep_days)
    and n.ciclo_estado in ('archivado','papelera') and not public.app_notificacion_requiere_accion_v034(n.id);
  get diagnostics v_notifs=row_count;
  -- Detailed sport session rows are compacted after the configured retention. Aggregate metrics remain.
  delete from public.sesiones_entrenamiento s where s.fecha < current_date-p.sports_detail_keep_days and s.estado in ('completada','cancelada') and s.ciclo_estado='archivado';
  get diagnostics v_sports=row_count;
  return jsonb_build_object('ok',true,'notifications',v_notifs,'invitations',v_invites,'admin_challenges',v_challenges,'admin_sessions',v_sessions,
    'deleted_conversations',v_contacts,'rejected_preinscriptions',v_pre,'old_sport_sessions',v_sports,'ran_at',now());
end $$;
revoke all on function public.app_kombax_retention_purge_v133() from public,anon,authenticated;
grant execute on function public.app_kombax_retention_purge_v133() to service_role;

create or replace function public.app_kombax_data_maintenance_v133()
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_lifecycle jsonb;v_purge jsonb;
begin
  v_lifecycle:=public.app_ciclo_mantenimiento_global_v133();
  v_purge:=public.app_kombax_retention_purge_v133();
  return jsonb_build_object('ok',true,'lifecycle',v_lifecycle,'retention',v_purge,'ran_at',now());
end $$;
revoke all on function public.app_kombax_data_maintenance_v133() from public,anon,authenticated;
grant execute on function public.app_kombax_data_maintenance_v133() to service_role;

-- Daily in-database maintenance: no network call and no secret exposed.
do $$
declare v_job bigint;
begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    select jobid into v_job from cron.job where jobname='kombax-data-lifecycle-daily-v133' limit 1;
    if v_job is not null then perform cron.unschedule(v_job); end if;
    perform cron.schedule('kombax-data-lifecycle-daily-v133','20 2 * * *',$cron$select public.app_kombax_data_maintenance_v133();$cron$);
  end if;
end $$;


notify pgrst,'reload schema';
commit;
