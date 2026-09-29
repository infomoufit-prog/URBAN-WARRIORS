-- KOMBAX R110 / build 20163 · ventana temporal de alta Club Piloto + seguimiento Owner.
-- No sustituye la arquitectura oficial de verificación: solo habilita un canal de alta
-- excepcional y acotado para los 4 clubes piloto autorizados. El Club creado es permanente.
begin;

insert into kombax_commercial.runtime_config_r64(config_key,value,description) values
 ('pilot_registration_open_at','"2026-09-29T00:00:00+02:00"','Apertura temporal del alta Club Piloto'),
 ('pilot_registration_close_at','"2026-11-16T00:00:00+01:00"','Cierre del alta Club Piloto; 15 noviembre completo'),
 ('pilot_operational_start_at','"2026-10-05T00:00:00+02:00"','Inicio operativo real de seguimiento del piloto'),
 ('pilot_operational_end_at','"2026-11-16T00:00:00+01:00"','Fin operativo del piloto; 15 noviembre completo'),
 ('pilot_club_slots','4','Máximo de clubes admitidos por la ventana Club Piloto')
on conflict(config_key) do update set value=excluded.value,description=excluded.description;

create table if not exists kombax_commercial.pilot_club_activations_r110(
  club_id uuid primary key references public.clubes(id) on delete cascade,
  manager_profile_id uuid not null references public.perfiles(id) on delete restrict,
  application_id uuid unique references public.kombax_solicitudes_alta(id) on delete set null,
  activated_at timestamptz not null default now(),
  activation_source text not null default 'pilot_window_r110',
  activation_status text not null default 'active' check(activation_status in ('active','founder','closed')),
  founder_eligible boolean not null default true,
  founder_program text,
  transitioned_at timestamptz,
  created_at timestamptz not null default now()
);
alter table kombax_commercial.pilot_club_activations_r110 enable row level security;
revoke all on kombax_commercial.pilot_club_activations_r110 from public,anon,authenticated;
grant all on kombax_commercial.pilot_club_activations_r110 to service_role;

create table if not exists kombax_commercial.pilot_club_invites_r110(
  id uuid primary key default gen_random_uuid(),
  code_hash text not null unique,
  label text not null,
  intended_email text,
  status text not null default 'pending' check(status in ('pending','used','revoked','expired')),
  expires_at timestamptz not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  used_by uuid references auth.users(id) on delete set null,
  used_club_id uuid references public.clubes(id) on delete set null,
  used_at timestamptz
);
alter table kombax_commercial.pilot_club_invites_r110 enable row level security;
revoke all on kombax_commercial.pilot_club_invites_r110 from public,anon,authenticated;
grant all on kombax_commercial.pilot_club_invites_r110 to service_role;

-- Owner genera el código una sola vez. En base de datos solo queda su hash.
create or replace function public.app_kombax_pilot_invite_create_r110(p_label text,p_email text default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_code text; v_hash text; v_close timestamptz; v_slots integer:=4; v_enrolled integer:=0; v_pending integer:=0; v_id uuid; v_email text:=lower(btrim(coalesce(p_email,'')));
begin
  if auth.uid() is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'platform_admin_required' using errcode='42501'; end if;
  if char_length(btrim(coalesce(p_label,'')))<2 then raise exception 'pilot_invite_label_required'; end if;
  if v_email<>'' and position('@' in v_email)<2 then raise exception 'pilot_invite_email_invalid'; end if;
  select trim(both '"' from value::text)::timestamptz into v_close from kombax_commercial.runtime_config_r64 where config_key='pilot_registration_close_at';
  select greatest(0,least(4,coalesce(value::text::integer,4))) into v_slots from kombax_commercial.runtime_config_r64 where config_key='pilot_club_slots';
  perform pg_advisory_xact_lock(hashtext('kombax-pilot-invites-r110'));
  update kombax_commercial.pilot_club_invites_r110 set status='expired' where status='pending' and expires_at<=now();
  select count(*) into v_enrolled from kombax_commercial.pilot_entities_r97 where subject_type='club';
  select count(*) into v_pending from kombax_commercial.pilot_club_invites_r110 where status='pending';
  -- Cada código pendiente reserva una plaza. Los códigos usados ya están representados por pilot_entities_r97.
  if v_enrolled+v_pending>=coalesce(v_slots,4) then raise exception 'pilot_invite_slots_full'; end if;
  v_code:='KX-PILOT-'||upper(substr(encode(extensions.gen_random_bytes(8),'hex'),1,12));
  v_hash:=encode(extensions.digest(v_code,'sha256'),'hex');
  insert into kombax_commercial.pilot_club_invites_r110(code_hash,label,intended_email,expires_at,created_by)
  values(v_hash,left(btrim(p_label),160),nullif(v_email,''),v_close,auth.uid()) returning id into v_id;
  return jsonb_build_object('ok',true,'invite_id',v_id,'code',v_code,'label',left(btrim(p_label),160),'intended_email',nullif(v_email,''),'expires_at',v_close);
end $$;
revoke all on function public.app_kombax_pilot_invite_create_r110(text,text) from public,anon,service_role;
grant execute on function public.app_kombax_pilot_invite_create_r110(text,text) to authenticated;

-- Estado público mínimo para pintar/retirar la ventana temporal sin exponer identidades.
create or replace function public.app_kombax_pilot_registration_window_r110()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_open timestamptz; v_close timestamptz; v_ops_start timestamptz; v_ops_end timestamptz;
  v_slots integer:=4; v_used integer:=0; v_reserved integer:=0; v_is_open boolean:=false;
begin
  select trim(both '"' from value::text)::timestamptz into v_open
  from kombax_commercial.runtime_config_r64 where config_key='pilot_registration_open_at';
  select trim(both '"' from value::text)::timestamptz into v_close
  from kombax_commercial.runtime_config_r64 where config_key='pilot_registration_close_at';
  select trim(both '"' from value::text)::timestamptz into v_ops_start
  from kombax_commercial.runtime_config_r64 where config_key='pilot_operational_start_at';
  select trim(both '"' from value::text)::timestamptz into v_ops_end
  from kombax_commercial.runtime_config_r64 where config_key='pilot_operational_end_at';
  select greatest(0,least(4,coalesce(value::text::integer,4))) into v_slots
  from kombax_commercial.runtime_config_r64 where config_key='pilot_club_slots';
  v_slots:=coalesce(v_slots,4);
  select count(*) into v_used from kombax_commercial.pilot_entities_r97 where subject_type='club';
  select count(*) into v_reserved from kombax_commercial.pilot_club_invites_r110 where status='pending' and expires_at>now();
  v_is_open:=coalesce(now()>=v_open and now()<v_close and v_used<v_slots,false);
  return jsonb_build_object(
    'open',v_is_open,'slots_total',v_slots,'slots_used',v_used,'slots_reserved',v_reserved,
    'slots_remaining',greatest(0,v_slots-v_used),'invites_available',greatest(0,v_slots-v_used-v_reserved),
    'registration_open_at',v_open,'registration_close_at',v_close,
    'operational_start_at',v_ops_start,'operational_end_at',v_ops_end,
    'plan_code','premium','document_verification_required',false,'club_persists_after_pilot',true
  );
end $$;
revoke all on function public.app_kombax_pilot_registration_window_r110() from public;
grant execute on function public.app_kombax_pilot_registration_window_r110() to anon,authenticated;

-- Alta autoservicio de Club Piloto. Mantiene el mismo tenant/club para toda su vida útil.
-- La excepción solo afecta a la documentación de verificación inicial; no elimina Auth,
-- correo confirmado, reglas de menores, RLS, roles ni los gates propios de Stripe/Commerce.
create or replace function public.app_kombax_pilot_club_activate_r110(p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid(); v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_email text; v_email_confirmed timestamptz; v_profile public.perfiles;
  v_type text; v_name text:=btrim(coalesce(v_payload->>'nombre_publico',''));
  v_phone text:=btrim(coalesce(v_payload->>'telefono','')); v_location text:=btrim(coalesce(v_payload->>'ubicacion',''));
  v_public jsonb; v_verify jsonb; v_club uuid; v_application uuid;
  v_open timestamptz; v_close timestamptz; v_pilot_end timestamptz; v_slots integer:=4; v_used integer:=0;
  v_existing public.app_mutation_requests; v_result jsonb; v_manager_name text; v_open_application uuid;
  v_pilot_code text:=upper(btrim(coalesce(v_payload->>'pilot_code',''))); v_pilot_hash text; v_invite kombax_commercial.pilot_club_invites_r110;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>'kombax.pilot.club.activate.r110' then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,null,'kombax.pilot.club.activate.r110');
  end if;

  select lower(coalesce(u.email,'')),u.email_confirmed_at into v_email,v_email_confirmed
  from auth.users u where u.id=v_uid and u.deleted_at is null;
  if v_email='' or v_email_confirmed is null then raise exception 'KOMBAX_EMAIL_VERIFICATION_REQUIRED'; end if;
  if v_pilot_code='' then raise exception 'KOMBAX_PILOT_INVITE_CODE_REQUIRED'; end if;
  v_pilot_hash:=encode(extensions.digest(v_pilot_code,'sha256'),'hex');
  select * into v_invite from kombax_commercial.pilot_club_invites_r110 i
  where i.code_hash=v_pilot_hash and i.status='pending' for update;
  if v_invite.id is null then raise exception 'KOMBAX_PILOT_INVITE_CODE_INVALID'; end if;
  if v_invite.expires_at<=now() then
    update kombax_commercial.pilot_club_invites_r110 set status='expired' where id=v_invite.id;
    raise exception 'KOMBAX_PILOT_INVITE_CODE_EXPIRED';
  end if;
  if v_invite.intended_email is not null and lower(v_invite.intended_email)<>v_email then raise exception 'KOMBAX_PILOT_INVITE_EMAIL_MISMATCH'; end if;
  select * into v_profile from public.perfiles p where p.id=v_uid;
  if v_profile.id is null then raise exception 'KOMBAX_PROFILE_REQUIRED'; end if;

  select account_type into v_type from public.kombax_account_types_r100 where user_id=v_uid;
  if v_type is null then
    insert into public.kombax_account_types_r100(user_id,account_type) values(v_uid,'club') on conflict do nothing;
    v_type:='club';
  end if;
  if v_type<>'club' then raise exception 'KOMBAX_PILOT_CLUB_ACCOUNT_REQUIRED'; end if;

  select trim(both '"' from value::text)::timestamptz into v_open
  from kombax_commercial.runtime_config_r64 where config_key='pilot_registration_open_at';
  select trim(both '"' from value::text)::timestamptz into v_close
  from kombax_commercial.runtime_config_r64 where config_key='pilot_registration_close_at';
  select trim(both '"' from value::text)::timestamptz into v_pilot_end
  from kombax_commercial.runtime_config_r64 where config_key='pilot_end_at';
  if v_open is null or v_close is null or now()<v_open or now()>=v_close then raise exception 'KOMBAX_PILOT_REGISTRATION_CLOSED'; end if;

  if char_length(v_name)<2 or char_length(v_name)>160 then raise exception 'KOMBAX_CLUB_NAME_INVALID'; end if;
  if v_location='' then raise exception 'KOMBAX_CLUB_LOCATION_REQUIRED'; end if;
  if jsonb_typeof(coalesce(v_payload->'disciplinas','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(v_payload->'disciplinas','[]'::jsonb))<1 then
    raise exception 'KOMBAX_CLUB_DISCIPLINES_REQUIRED';
  end if;
  if char_length(regexp_replace(v_phone,'[^0-9+]','','g'))<6 then raise exception 'KOMBAX_CLUB_PHONE_REQUIRED'; end if;
  if coalesce((v_payload->>'declaration')::boolean,false) is not true then raise exception 'KOMBAX_DECLARATION_REQUIRED'; end if;

  -- Una cuenta Club Piloto no crea un segundo Club ni consume otra plaza.
  select m.club_id into v_club
  from public.miembros_club m join public.clubes c on c.id=m.club_id
  where m.perfil_id=v_uid and m.activo and (m.rol='direccion' or m.coordinacion)
  order by m.creado_en limit 1;
  if v_club is not null then
    if exists(select 1 from kombax_commercial.pilot_entities_r97 p where p.subject_type='club' and p.subject_id=v_club) then
      select application_id into v_application from kombax_commercial.pilot_club_activations_r110 where club_id=v_club;
      v_result:=jsonb_build_object('ok',true,'reused',true,'club_id',v_club,'application_id',v_application,'plan_code','premium','document_verification_required',false,'founder_eligible',true);
      update public.app_mutation_requests set club_id=v_club,result=v_result,completed_at=now() where request_id=p_request_id;
      return v_result;
    end if;
    raise exception 'KOMBAX_ACCOUNT_ALREADY_MANAGES_CLUB';
  end if;

  perform pg_advisory_xact_lock(hashtext('kombax-pilot-club-slots'));
  select greatest(0,least(4,coalesce(value::text::integer,4))) into v_slots
  from kombax_commercial.runtime_config_r64 where config_key='pilot_club_slots';
  v_slots:=coalesce(v_slots,4);
  select count(*) into v_used from kombax_commercial.pilot_entities_r97 where subject_type='club';
  if v_used>=v_slots then raise exception 'KOMBAX_PILOT_CLUB_SLOTS_FULL'; end if;

  select s.id into v_open_application from public.kombax_solicitudes_alta s
  where s.perfil_id=v_uid and s.tipo='club' and s.estado in ('draft','submitted','under_review','needs_information')
  order by s.creado_en desc limit 1;
  if v_open_application is not null then
    update public.kombax_solicitudes_alta
    set estado='withdrawn',motivo_revision='Sustituida por alta temporal Club Piloto R110',actualizado_en=now()
    where id=v_open_application;
  end if;

  v_manager_name:=btrim(concat_ws(' ',nullif(v_profile.nombre,''),nullif(v_profile.apellidos,'')));
  if v_manager_name='' then v_manager_name:=split_part(v_email,'@',1); end if;
  v_public:=jsonb_build_object(
    'ubicacion',v_location,
    'ciudad',left(btrim(coalesce(v_payload->>'ciudad','')),120),
    'provincia',left(btrim(coalesce(v_payload->>'provincia','')),120),
    'pais',left(coalesce(nullif(btrim(v_payload->>'pais'),''),'España'),120),
    'disciplinas',coalesce(v_payload->'disciplinas','[]'::jsonb),
    'lema',left(btrim(coalesce(v_payload->>'lema','')),180),
    'descripcion',left(btrim(coalesce(v_payload->>'descripcion','')),1600),
    'web_publica',btrim(coalesce(v_payload->>'web_publica','')),
    'instagram',left(btrim(coalesce(v_payload->>'instagram','')),180)
  );
  v_verify:=jsonb_build_object(
    'pilot_activation',true,'verification_source','pilot_program_r110','document_bypass',true,
    'nombre_legal',v_name,'email_oficial',v_email,'telefono',v_phone,
    'responsable',v_manager_name,'rol_responsable','direccion','evidencia','pilot_program_r110_authorized'
  );

  v_club:=public.app_kombax_create_club_core_v097(v_uid,v_name,v_public,v_verify,v_uid);

  insert into public.kombax_solicitudes_alta(
    perfil_id,tipo,perfil_directo_id,club_id,nombre_publico,datos_publicos,datos_verificacion,estado,
    schema_version,declaracion_aceptada,declaracion_en,requisitos_version,enviado_en,revisado_por,revisado_en,motivo_revision
  ) values(
    v_uid,'club',null,v_club,v_name,v_public,v_verify,'verified',5,true,now(),'pilot-activation-r110',now(),v_uid,now(),
    'Validación automática por programa Club Piloto R110; no requiere documentación de verificación.'
  ) returning id into v_application;

  insert into public.kombax_verificacion_eventos(solicitud_id,perfil_directo_id,actor_perfil_id,evento,detalle)
  values(v_application,null,v_uid,'verified',jsonb_build_object('club_id',v_club,'source','pilot_program_r110','document_verification_required',false));

  insert into kombax_commercial.pilot_entities_r97(subject_type,subject_id,enrolled_by,founder_eligible,notes)
  values('club',v_club,v_uid,true,'Alta temporal Club Piloto R110; continuidad como Club fundador')
  on conflict(subject_type,subject_id) do update set founder_eligible=true,notes=excluded.notes;

  insert into kombax_commercial.plan_benefits_r97(subject_type,subject_id,benefit_code,plan_code,starts_at,ends_at,source,created_by)
  values('club',v_club,'PILOT_ACCESS','premium',now(),v_pilot_end,'pilot_activation_r110',v_uid)
  on conflict(subject_type,subject_id,benefit_code,starts_at) do nothing;

  insert into kombax_commercial.pilot_club_activations_r110(club_id,manager_profile_id,application_id,activated_at,activation_source,activation_status,founder_eligible)
  values(v_club,v_uid,v_application,now(),'pilot_window_r110','active',true)
  on conflict(club_id) do update set application_id=excluded.application_id,manager_profile_id=excluded.manager_profile_id,founder_eligible=true;

  update kombax_commercial.pilot_club_invites_r110
  set status='used',used_by=v_uid,used_club_id=v_club,used_at=now()
  where id=v_invite.id;

  insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle)
  values(v_uid,v_club,'kombax.pilot.club.activate.r110','club',v_club,
    jsonb_build_object('application_id',v_application,'plan_code','premium','document_verification_required',false,'founder_eligible',true));

  v_result:=jsonb_build_object('ok',true,'reused',false,'club_id',v_club,'application_id',v_application,
    'plan_code','premium','pilot_end_at',v_pilot_end,'document_verification_required',false,'founder_eligible',true,
    'member_linking_ready',true,'club_persists_after_pilot',true);
  update public.app_mutation_requests set club_id=v_club,result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_pilot_club_activate_r110(jsonb,uuid) from public,anon,service_role;
grant execute on function public.app_kombax_pilot_club_activate_r110(jsonb,uuid) to authenticated;

-- Owner: amplía el panel existente con adopción, vinculación de miembros y uso operativo.
create or replace function public.app_kombax_pilot_metrics_r97()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_rows jsonb; v_phase text; v_ops_start timestamptz; v_ops_end timestamptz;
  v_reg_open timestamptz; v_reg_close timestamptz; v_slots integer:=4; v_used integer:=0; v_reserved integer:=0; v_invites jsonb;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'platform_admin_required' using errcode='42501'; end if;
  v_phase:=kombax_commercial.program_phase_r97();
  select trim(both '"' from value::text)::timestamptz into v_ops_start from kombax_commercial.runtime_config_r64 where config_key='pilot_operational_start_at';
  select trim(both '"' from value::text)::timestamptz into v_ops_end from kombax_commercial.runtime_config_r64 where config_key='pilot_operational_end_at';
  select trim(both '"' from value::text)::timestamptz into v_reg_open from kombax_commercial.runtime_config_r64 where config_key='pilot_registration_open_at';
  select trim(both '"' from value::text)::timestamptz into v_reg_close from kombax_commercial.runtime_config_r64 where config_key='pilot_registration_close_at';
  select greatest(0,least(4,coalesce(value::text::integer,4))) into v_slots from kombax_commercial.runtime_config_r64 where config_key='pilot_club_slots';
  v_slots:=coalesce(v_slots,4);
  select count(*) into v_used from kombax_commercial.pilot_entities_r97 where subject_type='club';
  select count(*) into v_reserved from kombax_commercial.pilot_club_invites_r110 where status='pending' and expires_at>now();
  select coalesce(jsonb_agg(jsonb_build_object('invite_id',i.id,'label',i.label,'intended_email',i.intended_email,'status',i.status,'expires_at',i.expires_at,'created_at',i.created_at,'used_club_id',i.used_club_id,'used_at',i.used_at) order by i.created_at),'[]'::jsonb)
  into v_invites from kombax_commercial.pilot_club_invites_r110 i;

  select coalesce(jsonb_agg(jsonb_build_object(
    'subject_type',p.subject_type,'subject_id',p.subject_id,'name',coalesce(c.nombre,d.nombre_publico,'Organización'),
    'phase',case when v_phase='PILOT' then 'PILOT' else 'FOUNDER_PRELAUNCH' end,
    'enrolled_at',p.enrolled_at,'founder_eligible',p.founder_eligible,
    'activation_status',pa.activation_status,'activation_source',pa.activation_source,
    'available',coalesce(w.available,0),'reserved',coalesce(w.reserved,0),
    'granted',coalesce(g.granted,0),'used',coalesce(r.used,0),
    'assist_turns',coalesce(t.assist_turns,0),'migration_turns',coalesce(t.migration_turns,0),
    'api_cost',coalesce(t.api_cost,0),'imported_students',coalesce(i.students,0),
    'members_active',coalesce(m.members_active,0),'members_linked',coalesce(m.members_linked,0),
    'members_with_guardian',coalesce(m.members_with_guardian,0),'member_link_rate',coalesce(m.member_link_rate,0),
    'member_claims_pending',coalesce(mc.claims_pending,0),'member_claims_approved',coalesce(mc.claims_approved,0),
    'member_invites_sent',coalesce(inv.invites_sent,0),'member_invites_accepted',coalesce(inv.invites_accepted,0),
    'preinscriptions',coalesce(pre.preinscriptions,0),'training_sessions',coalesce(ses.training_sessions,0),
    'attendance_records',coalesce(att.attendance_records,0),'social_posts',coalesce(soc.social_posts,0),
    'public_events',coalesce(ev.public_events,0),
    'benefit',kombax_commercial.effective_benefit_r97(p.subject_type,p.subject_id,now())
  ) order by p.enrolled_at),'[]'::jsonb) into v_rows
  from kombax_commercial.pilot_entities_r97 p
  left join public.clubes c on p.subject_type='club' and c.id=p.subject_id
  left join public.perfiles_kombax_directos d on p.subject_type='direct_profile' and d.id=p.subject_id
  left join kombax_commercial.pilot_club_activations_r110 pa on p.subject_type='club' and pa.club_id=p.subject_id
  left join kombax_ai_ops.ai_wallets_r97 w on w.tenant_ref=p.tenant_ref
  left join lateral(select sum(total) granted from kombax_ai_ops.ai_credit_grants_r97 where tenant_ref=p.tenant_ref) g on true
  left join lateral(select sum(charged) used from kombax_ai_ops.ai_credit_reservations_r97 where tenant_ref=p.tenant_ref and status='SETTLED') r on true
  left join lateral(select count(*) filter(where category='MANAGEMENT' and status='COMPLETED') assist_turns,
      count(*) filter(where category='MIGRATION' and status='COMPLETED') migration_turns,
      coalesce(sum(estimated_cost) filter(where status='COMPLETED'),0) api_cost
      from kombax_ai_ops.assistance_turns where tenant_ref=p.tenant_ref and requested_at>=coalesce(v_ops_start,'-infinity'::timestamptz)) t on true
  left join lateral(select count(*) students from kombax_customer_ops.migration_imported_records_v271 mi
      join kombax_customer_ops.tickets ticket on ticket.ticket_id=mi.ticket_id
      where ticket.tenant_ref=p.tenant_ref and mi.kind='student' and mi.imported_at>=coalesce(v_ops_start,'-infinity'::timestamptz)) i on true
  left join lateral(select count(*) filter(where s.estado='activo') members_active,
      count(*) filter(where s.estado='activo' and (s.perfil_id is not null or s.kombax_vinculado_en is not null)) members_linked,
      count(*) filter(where s.estado='activo' and nullif(btrim(coalesce(s.tutor_nombre,'')),'') is not null) members_with_guardian,
      case when count(*) filter(where s.estado='activo')=0 then 0 else round(100.0*count(*) filter(where s.estado='activo' and (s.perfil_id is not null or s.kombax_vinculado_en is not null))/count(*) filter(where s.estado='activo'),1) end member_link_rate
      from public.socios s where p.subject_type='club' and s.club_id=p.subject_id) m on true
  left join lateral(select count(*) filter(where x.estado='pendiente') claims_pending,
      count(*) filter(where x.estado='aprobada' and x.resuelto_en>=coalesce(v_ops_start,'-infinity'::timestamptz)) claims_approved
      from public.kombax_membership_claims_r58 x where p.subject_type='club' and x.club_id=p.subject_id) mc on true
  left join lateral(select count(*) filter(where x.tipo_invitacion='alumno' and x.creado_en>=coalesce(v_ops_start,'-infinity'::timestamptz)) invites_sent,
      count(*) filter(where x.tipo_invitacion='alumno' and x.estado='aceptada' and x.aceptado_en>=coalesce(v_ops_start,'-infinity'::timestamptz)) invites_accepted
      from public.invitaciones_club x where p.subject_type='club' and x.club_id=p.subject_id) inv on true
  left join lateral(select count(*) preinscriptions from public.preinscripciones x
      where p.subject_type='club' and x.club_id=p.subject_id and x.creado_en>=coalesce(v_ops_start,'-infinity'::timestamptz)) pre on true
  left join lateral(select count(*) training_sessions from public.sesiones_entrenamiento x
      where p.subject_type='club' and x.club_id=p.subject_id and x.creado_en>=coalesce(v_ops_start,'-infinity'::timestamptz)) ses on true
  left join lateral(select count(*) attendance_records from public.asistencias x
      where p.subject_type='club' and x.club_id=p.subject_id and x.registrado_en>=coalesce(v_ops_start,'-infinity'::timestamptz)) att on true
  left join lateral(select count(*) social_posts
      from public.kombax_social_publicaciones post
      join public.kombax_social_perfiles sp on sp.id=post.autor_perfil_id
      left join public.identidades_sociales ids on sp.sujeto_tipo='miembro' and ids.id=sp.identidad_social_id
      where p.subject_type='club' and post.creado_en>=coalesce(v_ops_start,'-infinity'::timestamptz)
        and ((sp.sujeto_tipo='club' and sp.club_id=p.subject_id) or (sp.sujeto_tipo='miembro' and ids.club_origen_id=p.subject_id))) soc on true
  left join lateral(select count(*) public_events from public.kombax_eventos_publicos x
      where p.subject_type='club' and x.creador_tipo='club' and x.creador_club_id=p.subject_id and x.creado_en>=coalesce(v_ops_start,'-infinity'::timestamptz)) ev on true;

  return jsonb_build_object(
    'phase',v_phase,
    'pilot_start_at',(select value from kombax_commercial.runtime_config_r64 where config_key='pilot_start_at'),
    'pilot_end_at',(select value from kombax_commercial.runtime_config_r64 where config_key='pilot_end_at'),
    'operational_start_at',v_ops_start,'operational_end_at',v_ops_end,
    'registration_open_at',v_reg_open,'registration_close_at',v_reg_close,
    'registration_open',now()>=v_reg_open and now()<v_reg_close and v_used<v_slots,
    'slots_total',v_slots,'slots_used',v_used,'slots_reserved',v_reserved,
    'slots_remaining',greatest(0,v_slots-v_used),'invites_available',greatest(0,v_slots-v_used-v_reserved),'invites',v_invites,
    'official_launch_at',(select value from kombax_commercial.runtime_config_r64 where config_key='official_launch_at'),
    'entities',v_rows,'enrolled_count',jsonb_array_length(v_rows),
    'api_cost_total',(select coalesce(sum((x->>'api_cost')::numeric),0) from jsonb_array_elements(v_rows) x),
    'credits_used_total',(select coalesce(sum((x->>'used')::integer),0) from jsonb_array_elements(v_rows) x),
    'members_active_total',(select coalesce(sum((x->>'members_active')::integer),0) from jsonb_array_elements(v_rows) x),
    'members_linked_total',(select coalesce(sum((x->>'members_linked')::integer),0) from jsonb_array_elements(v_rows) x),
    'social_posts_total',(select coalesce(sum((x->>'social_posts')::integer),0) from jsonb_array_elements(v_rows) x),
    'public_events_total',(select coalesce(sum((x->>'public_events')::integer),0) from jsonb_array_elements(v_rows) x)
  );
end $$;
revoke all on function public.app_kombax_pilot_metrics_r97() from public,anon,service_role;
grant execute on function public.app_kombax_pilot_metrics_r97() to authenticated;

notify pgrst,'reload schema';
commit;
