-- KOMBAX R117 build 20172 · Pilot Club direct self-service.
-- During the configured pilot window, creating a Club does not wait for an
-- invitation code, documentary review or manual authorization. Verification
-- remains a separate capability/badge concern.

create or replace function public.app_kombax_create_pilot_club_core_r117(
  p_manager_perfil_id uuid,
  p_nombre_publico text,
  p_datos_publicos jsonb,
  p_datos_verificacion jsonb,
  p_actor_perfil_id uuid
)
returns uuid
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  v_public jsonb:=coalesce(p_datos_publicos,'{}'::jsonb);
  v_verify jsonb:=coalesce(p_datos_verificacion,'{}'::jsonb);
  v_nombre text:=btrim(coalesce(p_nombre_publico,''));
  v_slug text;
  v_club uuid;
  v_disc text;
  v_order smallint:=0;
  v_email text;
begin
  if p_manager_perfil_id is null or not exists(select 1 from public.perfiles p where p.id=p_manager_perfil_id) then raise exception 'KOMBAX_CLUB_MANAGER_PROFILE_REQUIRED'; end if;
  if p_actor_perfil_id is null or not exists(select 1 from public.perfiles p where p.id=p_actor_perfil_id) then raise exception 'KOMBAX_CLUB_ACTOR_PROFILE_REQUIRED'; end if;
  if char_length(v_nombre)<2 or char_length(v_nombre)>160 then raise exception 'KOMBAX_CLUB_NAME_INVALID'; end if;
  if exists(select 1 from public.clubes c where lower(btrim(c.nombre))=lower(v_nombre)) then raise exception 'KOMBAX_CLUB_ALREADY_EXISTS'; end if;

  select lower(coalesce(u.email,'')) into v_email from auth.users u where u.id=p_manager_perfil_id and u.deleted_at is null;
  if coalesce(v_email,'')='' then raise exception 'KOMBAX_EMAIL_REQUIRED'; end if;

  v_slug:=public.app_kombax_slug_v043(v_nombre);
  if char_length(coalesce(v_slug,''))<2 then raise exception 'KOMBAX_CLUB_SLUG_INVALID'; end if;
  if exists(select 1 from public.clubes c where c.slug=v_slug) then v_slug:=left(v_slug,50)||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,8); end if;

  insert into public.clubes(nombre,slug,lema,cif,telefono,email,direccion,web,activo,theme_id,branding_actualizado_por,branding_actualizado_en)
  values(
    v_nombre,v_slug,left(nullif(btrim(v_public->>'lema'),''),180),
    left(nullif(btrim(coalesce(v_verify->>'cif',v_verify->>'tax_id')),''),40),
    left(nullif(btrim(v_verify->>'telefono'),''),40),
    left(coalesce(nullif(btrim(coalesce(v_verify->>'email_oficial',v_verify->>'email')),''),v_email),254),
    left(coalesce(nullif(btrim(v_verify->>'direccion'),''),nullif(btrim(v_public->>'ubicacion'),'')),300),
    nullif(btrim(v_public->>'web_publica'),''),true,'combat-dark',p_actor_perfil_id,now()
  ) returning id into v_club;

  insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
  values(v_club,p_manager_perfil_id,'direccion',true,true)
  on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=true;

  update public.perfiles_club_publicos pc set
    nombre_publico=v_nombre,
    lema=left(nullif(btrim(v_public->>'lema'),''),180),
    descripcion=left(nullif(btrim(v_public->>'descripcion'),''),1600),
    ciudad=left(nullif(btrim(v_public->>'ciudad'),''),120),
    provincia=left(nullif(btrim(v_public->>'provincia'),''),120),
    pais=left(coalesce(nullif(btrim(v_public->>'pais'),''),'España'),120),
    contacto_publico=left(nullif(btrim(v_public->>'contacto_publico'),''),180),
    web_publica=nullif(btrim(v_public->>'web_publica'),''),
    instagram=left(nullif(btrim(v_public->>'instagram'),''),180),
    tiktok=left(nullif(btrim(v_public->>'tiktok'),''),180),
    youtube=left(nullif(btrim(v_public->>'youtube'),''),180),
    visible=true,moderacion_oculta=false,actualizado_por=p_actor_perfil_id,actualizado_en=now()
  where pc.club_id=v_club;

  if jsonb_typeof(v_public->'disciplinas')='array' then
    for v_disc in select distinct btrim(value) from jsonb_array_elements_text(v_public->'disciplinas') where btrim(value)<>'' limit 12 loop
      insert into public.disciplinas(club_id,nombre,activa,orden)
      values(v_club,left(v_disc,120),true,v_order)
      on conflict(club_id,nombre) do nothing;
      v_order:=v_order+1;
    end loop;
  end if;

  insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle)
  values(p_actor_perfil_id,v_club,'kombax.pilot.club.self_service.create','club',v_club,
    jsonb_build_object('manager_perfil_id',p_manager_perfil_id,'slug',v_slug,'source','pilot_open_self_service_r117','approval_required',false,'invite_code_required',false));
  return v_club;
end $$;

revoke all on function public.app_kombax_create_pilot_club_core_r117(uuid,text,jsonb,jsonb,uuid) from public,anon,authenticated;
grant execute on function public.app_kombax_create_pilot_club_core_r117(uuid,text,jsonb,jsonb,uuid) to service_role;

do $$
declare d text;
begin
  if to_regprocedure('public.app_kombax_application_validate_v072_legacy_r117(uuid)') is null then
    select pg_get_functiondef(p.oid) into d
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='app_kombax_application_validate_v072' and p.prokind='f';
    d:=replace(d,'CREATE OR REPLACE FUNCTION public.app_kombax_application_validate_v072(p_solicitud_id uuid)','CREATE FUNCTION public.app_kombax_application_validate_v072_legacy_r117(p_solicitud_id uuid)');
    execute d;
  end if;
end $$;

create or replace function public.app_kombax_application_validate_v072(p_solicitud_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_req public.kombax_solicitudes_alta;
  v_window jsonb;
begin
  select * into v_req from public.kombax_solicitudes_alta where id=p_solicitud_id;
  if v_req.id is null then raise exception 'KOMBAX_APPLICATION_NOT_FOUND'; end if;
  if v_req.tipo='club' then
    v_window:=public.app_kombax_pilot_registration_window_r110();
    if coalesce((v_window->>'open')::boolean,false) then
      if not coalesce(v_req.declaracion_aceptada,false) then raise exception 'KOMBAX_DECLARATION_REQUIRED'; end if;
      if char_length(btrim(coalesce(v_req.nombre_publico,'')))<2 then raise exception 'KOMBAX_CLUB_NAME_INVALID'; end if;
      return jsonb_build_object('valid',true,'tipo','club','pilot_open_self_service',true,'approval_required',false,'invite_code_required',false,'document_verification_required',false,'schema_version',v_req.schema_version);
    end if;
  end if;
  return public.app_kombax_application_validate_v072_legacy_r117(p_solicitud_id);
end $$;

create or replace function public.app_kombax_pilot_club_autoprovision_r117()
returns trigger
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  v_window jsonb;
  v_club uuid;
  v_slots integer:=4;
  v_used integer:=0;
  v_pilot_end timestamptz;
begin
  if new.tipo<>'club' or new.estado<>'submitted' or old.estado not in ('draft','needs_information') then return new; end if;
  v_window:=public.app_kombax_pilot_registration_window_r110();
  if not coalesce((v_window->>'open')::boolean,false) then return new; end if;

  if exists(select 1 from public.miembros_club m where m.perfil_id=new.perfil_id and m.activo and (m.rol='direccion' or m.coordinacion)) then
    select m.club_id into v_club from public.miembros_club m where m.perfil_id=new.perfil_id and m.activo and (m.rol='direccion' or m.coordinacion) order by m.creado_en limit 1;
  else
    perform pg_advisory_xact_lock(hashtext('kombax-pilot-club-slots'));
    select greatest(0,least(4,coalesce(value::text::integer,4))) into v_slots from kombax_commercial.runtime_config_r64 where config_key='pilot_club_slots';
    v_slots:=coalesce(v_slots,4);
    select count(*) into v_used from kombax_commercial.pilot_entities_r97 where subject_type='club';
    if v_used>=v_slots then raise exception 'KOMBAX_PILOT_CLUB_SLOTS_FULL'; end if;
    v_club:=public.app_kombax_create_pilot_club_core_r117(new.perfil_id,new.nombre_publico,new.datos_publicos,new.datos_verificacion,new.perfil_id);
  end if;

  new.club_id:=v_club;
  new.estado:='verified';
  new.requisitos_version:='pilot-open-self-service-r117';
  new.motivo_revision:=null;
  new.revisado_por:=null;
  new.revisado_en:=null;
  new.enviado_en:=coalesce(new.enviado_en,now());
  new.actualizado_en:=now();

  insert into kombax_commercial.pilot_entities_r97(subject_type,subject_id,enrolled_by,founder_eligible,notes)
  values('club',v_club,new.perfil_id,true,'Alta directa Club Piloto R117; sin aprobación previa')
  on conflict(subject_type,subject_id) do update set founder_eligible=true,notes=excluded.notes;

  select trim(both '"' from value::text)::timestamptz into v_pilot_end from kombax_commercial.runtime_config_r64 where config_key='pilot_end_at';
  if v_pilot_end is not null and v_pilot_end>now() then
    insert into kombax_commercial.plan_benefits_r97(subject_type,subject_id,benefit_code,plan_code,starts_at,ends_at,source,created_by)
    values('club',v_club,'PILOT_ACCESS','premium',now(),v_pilot_end,'pilot_open_self_service_r117',new.perfil_id)
    on conflict(subject_type,subject_id,benefit_code,starts_at) do nothing;
  end if;

  insert into kombax_commercial.pilot_club_activations_r110(club_id,manager_profile_id,application_id,activated_at,activation_source,activation_status,founder_eligible)
  values(v_club,new.perfil_id,new.id,now(),'pilot_open_self_service_r117','active',true)
  on conflict(club_id) do update set manager_profile_id=excluded.manager_profile_id,application_id=excluded.application_id,activation_source=excluded.activation_source,activation_status='active',founder_eligible=true;
  return new;
end $$;

drop trigger if exists trg_kombax_pilot_club_autoprovision_r117 on public.kombax_solicitudes_alta;
create trigger trg_kombax_pilot_club_autoprovision_r117
before update of estado on public.kombax_solicitudes_alta
for each row execute function public.app_kombax_pilot_club_autoprovision_r117();

create or replace function public.app_kombax_mis_solicitudes_v072()
returns table(id uuid,tipo text,perfil_directo_id uuid,nombre_publico text,datos_publicos jsonb,datos_verificacion jsonb,estado text,motivo_revision text,declaracion_aceptada boolean,enviado_en timestamptz,revisado_en timestamptz,actualizado_en timestamptz)
language sql stable security definer set search_path to 'public','auth'
as $$
  select s.id,s.tipo,s.perfil_directo_id,s.nombre_publico,s.datos_publicos,s.datos_verificacion,s.estado,s.motivo_revision,s.declaracion_aceptada,s.enviado_en,s.revisado_en,s.actualizado_en
  from public.kombax_solicitudes_alta s
  where (s.perfil_id=auth.uid() or (s.perfil_directo_id is not null and public.app_kombax_puede_gestionar_perfil_v070(s.perfil_directo_id,'admin')))
    and not (s.tipo='club' and s.club_id is not null and s.estado='verified' and coalesce(s.requisitos_version,'') like 'pilot-open%')
  order by s.creado_en desc;
$$;

create or replace function public.app_kombax_mis_solicitudes_v043()
returns table(id uuid,tipo text,perfil_directo_id uuid,nombre_publico text,datos_publicos jsonb,datos_verificacion jsonb,estado text,motivo_revision text,enviado_en timestamptz,revisado_en timestamptz,actualizado_en timestamptz)
language sql stable security definer set search_path to 'public','auth'
as $$
  select s.id,s.tipo,s.perfil_directo_id,s.nombre_publico,s.datos_publicos,s.datos_verificacion,s.estado,s.motivo_revision,s.enviado_en,s.revisado_en,s.actualizado_en
  from public.kombax_solicitudes_alta s
  where s.perfil_id=auth.uid()
    and not (s.tipo='club' and s.club_id is not null and s.estado='verified' and coalesce(s.requisitos_version,'') like 'pilot-open%')
  order by s.creado_en desc;
$$;

notify pgrst,'reload schema';
