-- KOMBAX R117 build 20172 · Pilot Hotfix 2
-- Date of birth is mandatory for every NEW KOMBAX account, regardless of the profile path.
-- It is private account data and is reused by later age-gated profile flows.
-- Applied live during pilot as birthdate_required_all_new_accounts_r117_18.

create or replace function public.crear_perfil_usuario()
returns trigger
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  v_dob date;
begin
  begin
    v_dob:=nullif(new.raw_user_meta_data->>'fecha_nacimiento','')::date;
  exception when others then
    raise exception 'KOMBAX_ACCOUNT_BIRTH_DATE_INVALID';
  end;

  if v_dob is null then
    raise exception 'KOMBAX_ACCOUNT_BIRTH_DATE_REQUIRED';
  end if;
  if v_dob>current_date or v_dob<date '1900-01-01' then
    raise exception 'KOMBAX_ACCOUNT_BIRTH_DATE_INVALID';
  end if;

  insert into public.perfiles(id,nombre,apellidos)
  values(
    new.id,
    coalesce(new.raw_user_meta_data->>'nombre',''),
    coalesce(new.raw_user_meta_data->>'apellidos','')
  )
  on conflict(id) do update
    set nombre=coalesce(nullif(excluded.nombre,''),public.perfiles.nombre),
        apellidos=coalesce(nullif(excluded.apellidos,''),public.perfiles.apellidos),
        actualizado_en=now();

  insert into public.kombax_account_private_r117(
    perfil_id,fecha_nacimiento,age_gate_version,source,actualizado_en
  )
  values(new.id,v_dob,'r117-signup-dob-v2','auth_signup_required',now())
  on conflict(perfil_id) do update
    set fecha_nacimiento=excluded.fecha_nacimiento,
        age_gate_version=excluded.age_gate_version,
        source=excluded.source,
        actualizado_en=now();

  return new;
end $$;

create or replace function public.app_kombax_account_birthdate_set_r117(p_fecha_nacimiento date)
returns jsonb
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  v_uid uuid:=auth.uid();
  v_age integer;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_fecha_nacimiento is null
     or p_fecha_nacimiento>current_date
     or p_fecha_nacimiento<date '1900-01-01' then
    raise exception 'KOMBAX_ACCOUNT_BIRTH_DATE_INVALID';
  end if;

  insert into public.kombax_account_private_r117(
    perfil_id,fecha_nacimiento,age_gate_version,source,actualizado_en
  )
  values(v_uid,p_fecha_nacimiento,'r117-signup-dob-v2','account_profile',now())
  on conflict(perfil_id) do update
    set fecha_nacimiento=excluded.fecha_nacimiento,
        age_gate_version=excluded.age_gate_version,
        source=excluded.source,
        actualizado_en=now();

  insert into public.kombax_member_private_r117(
    perfil_id,fecha_nacimiento,age_gate_version,actualizado_en
  )
  values(v_uid,p_fecha_nacimiento,'r117',now())
  on conflict(perfil_id) do update
    set fecha_nacimiento=excluded.fecha_nacimiento,
        age_gate_version='r117',
        actualizado_en=now();

  v_age:=extract(year from age(current_date,p_fecha_nacimiento))::integer;
  return jsonb_build_object(
    'ok',true,
    'fecha_nacimiento',p_fecha_nacimiento,
    'age',v_age,
    'age_16_plus',v_age>=16,
    'age_18_plus',v_age>=18
  );
end $$;

revoke all on function public.app_kombax_account_birthdate_set_r117(date) from public,anon;
grant execute on function public.app_kombax_account_birthdate_set_r117(date) to authenticated;

-- Reuse known, already verified dates for pre-hotfix accounts. Never invent a date.
insert into public.kombax_account_private_r117(perfil_id,fecha_nacimiento,age_gate_version,source,actualizado_en)
select x.perfil_id,x.fecha_nacimiento,'r117-backfill-v2',x.source,now()
from (
  select s.perfil_id,s.fecha_nacimiento,'club_member_record'::text as source,1 as priority
  from public.socios s
  where s.perfil_id is not null and s.fecha_nacimiento is not null
  union all
  select d.perfil_id,p.fecha_nacimiento,'direct_profile_private'::text,2
  from public.perfiles_kombax_directos d
  join public.kombax_perfil_persona_privada_v196 p on p.perfil_directo_id=d.id
  where p.fecha_nacimiento is not null
  union all
  select p.perfil_id,p.fecha_nacimiento,'member_private'::text,3
  from public.kombax_member_private_r117 p
  where p.fecha_nacimiento is not null
) x
where x.fecha_nacimiento between date '1900-01-01' and current_date
  and not exists(
    select 1 from public.kombax_account_private_r117 a where a.perfil_id=x.perfil_id
  )
order by x.priority
on conflict(perfil_id) do nothing;

-- Member self-service activation also updates the canonical private account age context.
do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_identity_mutate_v124' and p.prokind='f';

  d:=replace(
    d,
    'insert into public.kombax_member_private_r117(perfil_id,fecha_nacimiento,age_gate_version,actualizado_en)' || chr(10) ||
    '      values(v_uid,(p_payload->>''fecha_nacimiento'')::date,''r117'',now())' || chr(10) ||
    '      on conflict(perfil_id) do update set fecha_nacimiento=excluded.fecha_nacimiento,age_gate_version=''r117'',actualizado_en=now();',
    'perform public.app_kombax_account_birthdate_set_r117((p_payload->>''fecha_nacimiento'')::date);'
  );
  execute d;
end $$;

notify pgrst,'reload schema';
