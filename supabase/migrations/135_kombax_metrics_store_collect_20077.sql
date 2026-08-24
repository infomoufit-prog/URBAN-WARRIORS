begin;

-- Retention policy and aggregated business/consumption metrics
-- ---------------------------------------------------------------------------
create table if not exists public.kombax_retention_policy_v133(
  singleton boolean primary key default true check(singleton),
  trash_restore_days integer not null default 30 check(trash_restore_days between 1 and 90),
  notifications_keep_days integer not null default 180 check(notifications_keep_days between 30 and 730),
  invitation_history_days integer not null default 30 check(invitation_history_days between 7 and 365),
  rejected_preinscriptions_days integer not null default 365 check(rejected_preinscriptions_days between 30 and 1825),
  deleted_conversations_days integer not null default 30 check(deleted_conversations_days between 7 and 365),
  admin_challenges_days integer not null default 7 check(admin_challenges_days between 1 and 90),
  admin_sessions_days integer not null default 30 check(admin_sessions_days between 7 and 365),
  sports_detail_keep_days integer not null default 730 check(sports_detail_keep_days between 365 and 3650),
  updated_at timestamptz not null default now(),updated_by uuid references public.perfiles(id) on delete set null
);
insert into public.kombax_retention_policy_v133(singleton) values(true) on conflict(singleton) do nothing;
alter table public.kombax_retention_policy_v133 enable row level security;
revoke all on public.kombax_retention_policy_v133 from public,anon,authenticated;
grant select,insert,update,delete on public.kombax_retention_policy_v133 to service_role;

create table if not exists public.kombax_metrics_club_daily_v133(
  metric_date date not null,club_id uuid not null references public.clubes(id) on delete cascade,
  active_students integer not null default 0,new_students integer not null default 0,student_exits integer not null default 0,
  active_team integer not null default 0,sessions_scheduled integer not null default 0,sessions_completed integer not null default 0,
  attendance_records integer not null default 0,attendance_present integer not null default 0,reservations integer not null default 0,
  fees_created integer not null default 0,fees_amount numeric(14,2) not null default 0,
  payments_validated integer not null default 0,payments_amount numeric(14,2) not null default 0,
  receipts_issued integer not null default 0,receipts_amount numeric(14,2) not null default 0,
  material_orders integer not null default 0,community_posts integer not null default 0,community_likes integer not null default 0,
  notifications_created integer not null default 0,push_sent integer not null default 0,invitations_created integer not null default 0,
  social_posts integer not null default 0,social_messages integer not null default 0,showcase_leads integer not null default 0,
  showcase_items_active integer not null default 0,storage_objects integer not null default 0,storage_bytes bigint not null default 0,
  collected_at timestamptz not null default now(),primary key(metric_date,club_id)
);
alter table public.kombax_metrics_club_daily_v133 enable row level security;
revoke all on public.kombax_metrics_club_daily_v133 from public,anon,authenticated;
grant select,insert,update,delete on public.kombax_metrics_club_daily_v133 to service_role;
create index if not exists idx_kombax_metrics_club_date_v133 on public.kombax_metrics_club_daily_v133(club_id,metric_date desc);

create table if not exists public.kombax_metrics_platform_daily_v133(
  metric_date date primary key,active_clubs integer not null default 0,accounts_total integer not null default 0,new_accounts integer not null default 0,
  active_students integer not null default 0,sessions integer not null default 0,attendance_records integer not null default 0,
  fees_created integer not null default 0,payments_validated integer not null default 0,payments_amount numeric(14,2) not null default 0,
  receipts_issued integer not null default 0,community_posts integer not null default 0,social_posts integer not null default 0,
  social_comments integer not null default 0,social_likes integer not null default 0,social_messages integer not null default 0,
  showcase_leads integer not null default 0,notifications_created integer not null default 0,push_sent integer not null default 0,
  invitations_created integer not null default 0,audited_actions integer not null default 0,storage_objects integer not null default 0,storage_bytes bigint not null default 0,
  collected_at timestamptz not null default now()
);
alter table public.kombax_metrics_platform_daily_v133 enable row level security;
revoke all on public.kombax_metrics_platform_daily_v133 from public,anon,authenticated;
grant select,insert,update,delete on public.kombax_metrics_platform_daily_v133 to service_role;

create or replace function public.app_kombax_metrics_collect_date_v133(p_date date default current_date)
returns jsonb language plpgsql security definer set search_path=public,auth,storage as $$
declare v_club record;v_storage_objects int;v_storage_bytes bigint;v_clubs int:=0;
begin
  if p_date is null or p_date>current_date then raise exception 'METRICS_DATE_INVALID'; end if;
  for v_club in select id from public.clubes loop
    select count(*)::int,coalesce(sum((o.metadata->>'size')::bigint),0)::bigint into v_storage_objects,v_storage_bytes
    from storage.objects o where split_part(o.name,'/',1)=v_club.id::text and o.bucket_id in ('club-public-media','community-media','justificantes-pago','member-documents','profile-media','sports-profile-media');
    v_storage_objects:=v_storage_objects+(select count(*)::int from public.kombax_social_media sm join public.kombax_social_perfiles sp on sp.id=sm.social_profile_id where sp.club_id=v_club.id and sm.estado='active');
    v_storage_bytes:=v_storage_bytes+coalesce((select sum(sm.bytes)::bigint from public.kombax_social_media sm join public.kombax_social_perfiles sp on sp.id=sm.social_profile_id where sp.club_id=v_club.id and sm.estado='active'),0);
    insert into public.kombax_metrics_club_daily_v133(
      metric_date,club_id,active_students,new_students,student_exits,active_team,sessions_scheduled,sessions_completed,attendance_records,attendance_present,reservations,
      fees_created,fees_amount,payments_validated,payments_amount,receipts_issued,receipts_amount,material_orders,community_posts,community_likes,
      notifications_created,push_sent,invitations_created,social_posts,social_messages,showcase_leads,showcase_items_active,storage_objects,storage_bytes,collected_at)
    select p_date,v_club.id,
      (select count(*) from public.socios s where s.club_id=v_club.id and s.fecha_alta<=p_date and (s.fecha_baja is null or s.fecha_baja>p_date)),
      (select count(*) from public.socios s where s.club_id=v_club.id and s.fecha_alta=p_date),
      (select count(*) from public.socios s where s.club_id=v_club.id and s.fecha_baja=p_date),
      (select count(*) from public.miembros_club m where m.club_id=v_club.id and m.activo and m.creado_en::date<=p_date),
      (select count(*) from public.sesiones_entrenamiento x where x.club_id=v_club.id and x.fecha=p_date and x.estado<>'cancelada'),
      (select count(*) from public.sesiones_entrenamiento x where x.club_id=v_club.id and x.fecha=p_date and x.estado='completada'),
      (select count(*) from public.asistencias x where x.club_id=v_club.id and x.registrado_en::date=p_date),
      (select count(*) from public.asistencias x where x.club_id=v_club.id and x.registrado_en::date=p_date and x.estado in ('presente','retraso')),
      (select count(*) from public.reservas_sesion x where x.club_id=v_club.id and x.creado_en::date=p_date),
      (select count(*) from public.cuotas x where x.club_id=v_club.id and x.creado_en::date=p_date),
      coalesce((select sum(x.importe) from public.cuotas x where x.club_id=v_club.id and x.creado_en::date=p_date),0),
      (select count(*) from public.pagos x where x.club_id=v_club.id and x.fecha=p_date and x.estado_validacion='validado'),
      coalesce((select sum(x.importe) from public.pagos x where x.club_id=v_club.id and x.fecha=p_date and x.estado_validacion='validado'),0),
      (select count(*) from public.recibos_cuota x where x.club_id=v_club.id and x.fecha_pago=p_date and x.anulado_en is null),
      coalesce((select sum(x.importe) from public.recibos_cuota x where x.club_id=v_club.id and x.fecha_pago=p_date and x.anulado_en is null),0),
      (select count(*) from public.material_pedidos x where x.club_id=v_club.id and x.creado_en::date=p_date),
      (select count(*) from public.publicaciones_comunidad x where x.club_id=v_club.id and x.creado_en::date=p_date),
      (select count(*) from public.comunidad_likes x where x.club_id=v_club.id and x.creado_en::date=p_date),
      (select count(*) from public.notificaciones x where x.club_id=v_club.id and x.creado_en::date=p_date),
      (select count(*) from public.notificaciones x where x.club_id=v_club.id and x.push_enviado_en::date=p_date),
      (select count(*) from public.invitaciones_club x where x.club_id=v_club.id and x.creado_en::date=p_date),
      (select count(*) from public.kombax_social_publicaciones x join public.kombax_social_perfiles sp on sp.id=x.autor_perfil_id where sp.club_id=v_club.id and x.creado_en::date=p_date),
      (select count(*) from public.kombax_social_contacto_mensajes m join public.kombax_social_contactos c on c.id=m.contacto_id where m.creado_en::date=p_date and (c.remitente_social_id in (select id from public.kombax_social_perfiles where club_id=v_club.id) or c.destinatario_social_id in (select id from public.kombax_social_perfiles where club_id=v_club.id))),
      (select count(*) from public.kombax_social_contactos c join public.kombax_showcase_elementos e on e.id=c.showcase_elemento_id join public.kombax_showcase_marcas b on b.id=e.marca_id where b.club_id=v_club.id and c.canal='showcase' and c.creado_en::date=p_date),
      (select count(*) from public.kombax_showcase_elementos e join public.kombax_showcase_marcas b on b.id=e.marca_id where b.club_id=v_club.id and e.estado='publicado' and e.creado_en::date<=p_date),
      case when p_date=current_date then v_storage_objects else 0 end,case when p_date=current_date then v_storage_bytes else 0 end,now()
    on conflict(metric_date,club_id) do update set
      active_students=excluded.active_students,new_students=excluded.new_students,student_exits=excluded.student_exits,active_team=excluded.active_team,
      sessions_scheduled=excluded.sessions_scheduled,sessions_completed=excluded.sessions_completed,attendance_records=excluded.attendance_records,attendance_present=excluded.attendance_present,reservations=excluded.reservations,
      fees_created=excluded.fees_created,fees_amount=excluded.fees_amount,payments_validated=excluded.payments_validated,payments_amount=excluded.payments_amount,
      receipts_issued=excluded.receipts_issued,receipts_amount=excluded.receipts_amount,material_orders=excluded.material_orders,community_posts=excluded.community_posts,community_likes=excluded.community_likes,
      notifications_created=excluded.notifications_created,push_sent=excluded.push_sent,invitations_created=excluded.invitations_created,social_posts=excluded.social_posts,social_messages=excluded.social_messages,
      showcase_leads=excluded.showcase_leads,showcase_items_active=excluded.showcase_items_active,
      storage_objects=case when excluded.metric_date=current_date then excluded.storage_objects else 0 end,
      storage_bytes=case when excluded.metric_date=current_date then excluded.storage_bytes else 0 end,collected_at=now();
    v_clubs:=v_clubs+1;
  end loop;

  select count(*)::int,coalesce(sum((metadata->>'size')::bigint),0)::bigint into v_storage_objects,v_storage_bytes from storage.objects;
  insert into public.kombax_metrics_platform_daily_v133(
    metric_date,active_clubs,accounts_total,new_accounts,active_students,sessions,attendance_records,fees_created,payments_validated,payments_amount,receipts_issued,
    community_posts,social_posts,social_comments,social_likes,social_messages,showcase_leads,notifications_created,push_sent,invitations_created,audited_actions,storage_objects,storage_bytes,collected_at)
  select p_date,
    (select count(*) from public.clubes where activo and creado_en::date<=p_date),
    (select count(*) from public.perfiles where creado_en::date<=p_date),(select count(*) from public.perfiles where creado_en::date=p_date),
    (select count(*) from public.socios where fecha_alta<=p_date and (fecha_baja is null or fecha_baja>p_date)),
    (select count(*) from public.sesiones_entrenamiento where fecha=p_date and estado<>'cancelada'),
    (select count(*) from public.asistencias where registrado_en::date=p_date),
    (select count(*) from public.cuotas where creado_en::date=p_date),
    (select count(*) from public.pagos where fecha=p_date and estado_validacion='validado'),
    coalesce((select sum(importe) from public.pagos where fecha=p_date and estado_validacion='validado'),0),
    (select count(*) from public.recibos_cuota where fecha_pago=p_date and anulado_en is null),
    (select count(*) from public.publicaciones_comunidad where creado_en::date=p_date),
    (select count(*) from public.kombax_social_publicaciones where creado_en::date=p_date),
    (select count(*) from public.kombax_social_comentarios where creado_en::date=p_date),
    (select count(*) from public.kombax_social_likes where creado_en::date=p_date),
    (select count(*) from public.kombax_social_contacto_mensajes where creado_en::date=p_date),
    (select count(*) from public.kombax_social_contactos where canal='showcase' and creado_en::date=p_date),
    (select count(*) from public.notificaciones where creado_en::date=p_date),
    (select count(*) from public.notificaciones where push_enviado_en::date=p_date),
    (select count(*) from public.invitaciones_club where creado_en::date=p_date),
    (select count(*) from public.kombax_actor_audit where creado_en::date=p_date),
    case when p_date=current_date then v_storage_objects else 0 end,case when p_date=current_date then v_storage_bytes else 0 end,now()
  on conflict(metric_date) do update set
    active_clubs=excluded.active_clubs,accounts_total=excluded.accounts_total,new_accounts=excluded.new_accounts,active_students=excluded.active_students,
    sessions=excluded.sessions,attendance_records=excluded.attendance_records,fees_created=excluded.fees_created,payments_validated=excluded.payments_validated,payments_amount=excluded.payments_amount,
    receipts_issued=excluded.receipts_issued,community_posts=excluded.community_posts,social_posts=excluded.social_posts,social_comments=excluded.social_comments,social_likes=excluded.social_likes,
    social_messages=excluded.social_messages,showcase_leads=excluded.showcase_leads,notifications_created=excluded.notifications_created,push_sent=excluded.push_sent,
    invitations_created=excluded.invitations_created,audited_actions=excluded.audited_actions,
    storage_objects=case when excluded.metric_date=current_date then excluded.storage_objects else 0 end,
    storage_bytes=case when excluded.metric_date=current_date then excluded.storage_bytes else 0 end,collected_at=now();
  return jsonb_build_object('ok',true,'metric_date',p_date,'clubs',v_clubs);
end $$;
revoke all on function public.app_kombax_metrics_collect_date_v133(date) from public,anon,authenticated;
grant execute on function public.app_kombax_metrics_collect_date_v133(date) to service_role;


notify pgrst,'reload schema';
commit;
