-- KOMBAX R117 pilot hotfix: Club Piloto is open self-service during the configured window.
-- Invitation codes are disabled and no longer reserve pilot slots.

update kombax_commercial.pilot_club_invites_r110
set status='revoked'
where status='pending';

create or replace function public.app_kombax_pilot_invite_create_r110(p_label text,p_email text default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
begin
  raise exception 'PILOT_INVITE_CODES_DISABLED';
end $$;

revoke all on function public.app_kombax_pilot_invite_create_r110(text,text) from public,anon,authenticated,service_role;

create or replace function public.app_kombax_pilot_registration_window_r110()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_open timestamptz; v_close timestamptz; v_ops_start timestamptz; v_ops_end timestamptz;
  v_slots integer:=4; v_used integer:=0; v_is_open boolean:=false;
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
  v_is_open:=coalesce(now()>=v_open and now()<v_close and v_used<v_slots,false);
  return jsonb_build_object(
    'open',v_is_open,'registration_mode','open','invite_code_required',false,
    'slots_total',v_slots,'slots_used',v_used,'slots_reserved',0,
    'slots_remaining',greatest(0,v_slots-v_used),
    'registration_open_at',v_open,'registration_close_at',v_close,
    'operational_start_at',v_ops_start,'operational_end_at',v_ops_end,
    'plan_code','premium','document_verification_required',false,'club_persists_after_pilot',true
  );
end $$;
revoke all on function public.app_kombax_pilot_registration_window_r110() from public;
grant execute on function public.app_kombax_pilot_registration_window_r110() to anon,authenticated;

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
      v_result:=jsonb_build_object('ok',true,'reused',true,'club_id',v_club,'application_id',v_application,'plan_code','premium','document_verification_required',false,'founder_eligible',true,'invite_code_required',false,'registration_mode','open');
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
    set estado='withdrawn',motivo_revision='Sustituida por alta temporal Club Piloto R117',actualizado_en=now()
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
    'pilot_activation',true,'verification_source','pilot_program_open_r117','registration_mode','open','invite_code_required',false,'document_bypass',true,
    'nombre_legal',v_name,'email_oficial',v_email,'telefono',v_phone,
    'responsable',v_manager_name,'rol_responsable','direccion','evidencia','pilot_program_open_registration_r117'
  );

  v_club:=public.app_kombax_create_club_core_v097(v_uid,v_name,v_public,v_verify,v_uid);

  insert into public.kombax_solicitudes_alta(
    perfil_id,tipo,perfil_directo_id,club_id,nombre_publico,datos_publicos,datos_verificacion,estado,
    schema_version,declaracion_aceptada,declaracion_en,requisitos_version,enviado_en,revisado_por,revisado_en,motivo_revision
  ) values(
    v_uid,'club',null,v_club,v_name,v_public,v_verify,'verified',5,true,now(),'pilot-open-r117',now(),v_uid,now(),
    'Validación automática por alta abierta de Club Piloto R117; no requiere código ni documentación inicial.'
  ) returning id into v_application;

  insert into public.kombax_verificacion_eventos(solicitud_id,perfil_directo_id,actor_perfil_id,evento,detalle)
  values(v_application,null,v_uid,'verified',jsonb_build_object('club_id',v_club,'source','pilot_program_open_r117','invite_code_required',false,'document_verification_required',false));

  insert into kombax_commercial.pilot_entities_r97(subject_type,subject_id,enrolled_by,founder_eligible,notes)
  values('club',v_club,v_uid,true,'Alta abierta Club Piloto R117; continuidad como Club fundador')
  on conflict(subject_type,subject_id) do update set founder_eligible=true,notes=excluded.notes;

  insert into kombax_commercial.plan_benefits_r97(subject_type,subject_id,benefit_code,plan_code,starts_at,ends_at,source,created_by)
  values('club',v_club,'PILOT_ACCESS','premium',now(),v_pilot_end,'pilot_open_registration_r117',v_uid)
  on conflict(subject_type,subject_id,benefit_code,starts_at) do nothing;

  insert into kombax_commercial.pilot_club_activations_r110(club_id,manager_profile_id,application_id,activated_at,activation_source,activation_status,founder_eligible)
  values(v_club,v_uid,v_application,now(),'pilot_open_window_r117','active',true)
  on conflict(club_id) do update set application_id=excluded.application_id,manager_profile_id=excluded.manager_profile_id,founder_eligible=true;

  insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle)
  values(v_uid,v_club,'kombax.pilot.club.activate.r110','club',v_club,
    jsonb_build_object('application_id',v_application,'plan_code','premium','registration_mode','open','invite_code_required',false,'document_verification_required',false,'founder_eligible',true));

  v_result:=jsonb_build_object('ok',true,'reused',false,'club_id',v_club,'application_id',v_application,
    'plan_code','premium','pilot_end_at',v_pilot_end,'registration_mode','open','invite_code_required',false,'document_verification_required',false,'founder_eligible',true,
    'member_linking_ready',true,'club_persists_after_pilot',true);
  update public.app_mutation_requests set club_id=v_club,result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_pilot_club_activate_r110(jsonb,uuid) from public,anon,service_role;
grant execute on function public.app_kombax_pilot_club_activate_r110(jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
