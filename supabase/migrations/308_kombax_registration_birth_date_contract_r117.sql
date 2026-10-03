-- KOMBAX R117 build 20172 · one birth-date contract for every new Auth account.
-- DOB is private, required at signup, normalized to ISO YYYY-MM-DD and persisted
-- in kombax_account_private_r117. Historical accounts are backfilled only when
-- all available canonical sources agree; otherwise they are prompted once.

create or replace function public.app_kombax_birth_date_validate_r117(p_fecha date)
returns integer language plpgsql stable security definer set search_path to 'public'
as $$
declare v_age integer;
begin
  if p_fecha is null then raise exception 'KOMBAX_ACCOUNT_BIRTH_DATE_REQUIRED'; end if;
  if p_fecha>current_date or p_fecha<date '1900-01-01' then raise exception 'KOMBAX_ACCOUNT_BIRTH_DATE_INVALID'; end if;
  v_age:=extract(year from age(current_date,p_fecha))::integer;
  return v_age;
end $$;
revoke all on function public.app_kombax_birth_date_validate_r117(date) from public,anon;
grant execute on function public.app_kombax_birth_date_validate_r117(date) to authenticated,service_role;

create or replace function public.crear_perfil_usuario()
returns trigger language plpgsql security definer set search_path to 'public','auth'
as $$
declare
  v_dob date;
  v_raw text:=btrim(coalesce(new.raw_user_meta_data->>'fecha_nacimiento',''));
begin
  if v_raw='' then raise exception 'KOMBAX_ACCOUNT_BIRTH_DATE_REQUIRED'; end if;
  begin
    if v_raw !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'KOMBAX_ACCOUNT_BIRTH_DATE_INVALID'; end if;
    v_dob:=v_raw::date;
  exception when others then
    raise exception 'KOMBAX_ACCOUNT_BIRTH_DATE_INVALID';
  end;
  perform public.app_kombax_birth_date_validate_r117(v_dob);

  insert into public.perfiles(id,nombre,apellidos)
  values(new.id,coalesce(new.raw_user_meta_data->>'nombre',''),coalesce(new.raw_user_meta_data->>'apellidos',''))
  on conflict(id) do update set nombre=coalesce(nullif(excluded.nombre,''),public.perfiles.nombre),apellidos=coalesce(nullif(excluded.apellidos,''),public.perfiles.apellidos),actualizado_en=now();

  insert into public.kombax_account_private_r117(perfil_id,fecha_nacimiento,age_gate_version,source,actualizado_en)
  values(new.id,v_dob,'r117-signup-dob-v3','auth_signup_required',now())
  on conflict(perfil_id) do update set fecha_nacimiento=excluded.fecha_nacimiento,age_gate_version=excluded.age_gate_version,source=excluded.source,actualizado_en=now();
  return new;
end $$;

create or replace function public.app_kombax_account_birth_date_status_r117()
returns jsonb language plpgsql stable security definer set search_path to 'public','auth'
as $$
declare v_uid uuid:=auth.uid();v_row public.kombax_account_private_r117;v_age integer;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_row from public.kombax_account_private_r117 where perfil_id=v_uid;
  if v_row.perfil_id is null then return jsonb_build_object('present',false,'required',true,'age',null,'source',null,'version','r117-signup-dob-v3'); end if;
  v_age:=public.app_kombax_birth_date_validate_r117(v_row.fecha_nacimiento);
  return jsonb_build_object('present',true,'required',false,'age',v_age,'source',v_row.source,'version',v_row.age_gate_version);
end $$;
revoke all on function public.app_kombax_account_birth_date_status_r117() from public,anon;
grant execute on function public.app_kombax_account_birth_date_status_r117() to authenticated;

create or replace function public.app_kombax_account_birth_date_set_r117(p_fecha_nacimiento date)
returns jsonb language plpgsql security definer set search_path to 'public','auth'
as $$
declare v_uid uuid:=auth.uid();v_age integer;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  v_age:=public.app_kombax_birth_date_validate_r117(p_fecha_nacimiento);
  insert into public.kombax_account_private_r117(perfil_id,fecha_nacimiento,age_gate_version,source,actualizado_en)
  values(v_uid,p_fecha_nacimiento,'r117-signup-dob-v3','self_service_completion',now())
  on conflict(perfil_id) do update set fecha_nacimiento=excluded.fecha_nacimiento,age_gate_version=excluded.age_gate_version,source=excluded.source,actualizado_en=now();
  update auth.users set raw_user_meta_data=coalesce(raw_user_meta_data,'{}'::jsonb)||jsonb_build_object('fecha_nacimiento',p_fecha_nacimiento::text),updated_at=now() where id=v_uid;
  return jsonb_build_object('ok',true,'present',true,'required',false,'age',v_age,'version','r117-signup-dob-v3');
end $$;
revoke all on function public.app_kombax_account_birth_date_set_r117(date) from public,anon;
grant execute on function public.app_kombax_account_birth_date_set_r117(date) to authenticated;

with candidate_dates as (
  select u.id perfil_id,case when btrim(coalesce(u.raw_user_meta_data->>'fecha_nacimiento','')) ~ '^\d{4}-\d{2}-\d{2}$' then (u.raw_user_meta_data->>'fecha_nacimiento')::date else null end fecha
  from auth.users u where u.deleted_at is null
  union all select s.perfil_id,s.fecha_nacimiento from public.socios s where s.perfil_id is not null and s.fecha_nacimiento is not null
  union all select d.perfil_id,p.fecha_nacimiento from public.perfiles_kombax_directos d join public.kombax_perfil_persona_privada_v196 p on p.perfil_directo_id=d.id where d.perfil_id is not null and p.fecha_nacimiento is not null
  union all select d.perfil_id,d.fecha_nacimiento_verificada from public.perfiles_kombax_directos d where d.perfil_id is not null and d.fecha_nacimiento_verificada is not null
), resolved as (
  select perfil_id,min(fecha) fecha from candidate_dates where fecha is not null and fecha between date '1900-01-01' and current_date group by perfil_id having count(distinct fecha)=1
)
insert into public.kombax_account_private_r117(perfil_id,fecha_nacimiento,age_gate_version,source,actualizado_en)
select r.perfil_id,r.fecha,'r117-signup-dob-v3','canonical_backfill',now() from resolved r
join auth.users u on u.id=r.perfil_id and u.deleted_at is null
where not exists(select 1 from public.kombax_account_private_r117 a where a.perfil_id=r.perfil_id)
on conflict(perfil_id) do nothing;

create or replace function public.app_kombax_profile_taxonomy_v196()
returns jsonb language sql stable set search_path to 'public'
as $$
  select jsonb_build_object(
    'profile_types',jsonb_build_array(
      jsonb_build_object('code','club','kind','tenant','verification','required_for_badge_and_sensitive_capabilities'),
      jsonb_build_object('code','miembro','kind','membership','verification','club_age_relation'),
      jsonb_build_object('code','competidor','kind','direct','min_age',16,'verification','required_for_badge'),
      jsonb_build_object('code','marca','kind','direct','verification','required_for_sensitive_capabilities'),
      jsonb_build_object('code','federacion','kind','direct','verification','required_for_sensitive_capabilities'),
      jsonb_build_object('code','profesional','kind','direct','min_age',18,'verification','required_for_sensitive_capabilities'),
      jsonb_build_object('code','media','kind','direct','verification','required_for_sensitive_capabilities'),
      jsonb_build_object('code','espectador','kind','direct','min_age',16,'verification','none','public_profile_default',true)
    ),
    'professional_specialties',coalesce((select jsonb_agg(jsonb_build_object('code',s.codigo,'name',s.nombre,'description',s.descripcion) order by s.orden,s.nombre) from public.kombax_profesional_especialidades_v196 s where s.activa),'[]'::jsonb),
    'competitor_is_professional_subtype',false,
    'version','r117-signup-contract-v3'
  );
$$;

notify pgrst,'reload schema';
