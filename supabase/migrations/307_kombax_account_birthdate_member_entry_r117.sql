-- KOMBAX R117 build 20172 · Pilot Hotfix 2
-- Required date of birth at account signup + private reusable age context.
-- Applied live during pilot as account_birthdate_and_member_entry_pilot_r117_17.

create table if not exists public.kombax_account_private_r117(
  perfil_id uuid primary key references public.perfiles(id) on delete cascade,
  fecha_nacimiento date not null,
  age_gate_version text not null default 'r117-signup-dob-v1',
  source text not null default 'signup',
  actualizado_en timestamptz not null default now()
);
alter table public.kombax_account_private_r117 enable row level security;
revoke all on table public.kombax_account_private_r117 from public,anon,authenticated;

create or replace function public.crear_perfil_usuario()
returns trigger
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  v_dob date;
begin
  insert into public.perfiles(id,nombre,apellidos)
  values(new.id,coalesce(new.raw_user_meta_data->>'nombre',''),coalesce(new.raw_user_meta_data->>'apellidos',''))
  on conflict(id) do nothing;

  begin
    v_dob:=nullif(new.raw_user_meta_data->>'fecha_nacimiento','')::date;
  exception when others then
    v_dob:=null;
  end;

  if v_dob is not null and v_dob<=current_date and v_dob>=date '1900-01-01' then
    insert into public.kombax_account_private_r117(perfil_id,fecha_nacimiento,age_gate_version,source,actualizado_en)
    values(new.id,v_dob,'r117-signup-dob-v1','auth_metadata',now())
    on conflict(perfil_id) do update
      set fecha_nacimiento=excluded.fecha_nacimiento,
          age_gate_version=excluded.age_gate_version,
          source=excluded.source,
          actualizado_en=now();
  end if;
  return new;
end $$;

insert into public.kombax_account_private_r117(perfil_id,fecha_nacimiento,age_gate_version,source,actualizado_en)
select u.id,(u.raw_user_meta_data->>'fecha_nacimiento')::date,'r117-signup-dob-v1','auth_metadata_backfill',now()
from auth.users u
join public.perfiles p on p.id=u.id
where coalesce(u.raw_user_meta_data->>'fecha_nacimiento','') ~ '^\d{4}-\d{2}-\d{2}$'
  and (u.raw_user_meta_data->>'fecha_nacimiento')::date between date '1900-01-01' and current_date
on conflict(perfil_id) do nothing;

create or replace function public.app_kombax_account_age_context_r117()
returns jsonb
language sql
stable
security definer
set search_path to 'public','auth'
as $$
  select case
    when auth.uid() is null then jsonb_build_object('available',false)
    when p.perfil_id is null then jsonb_build_object('available',false)
    else jsonb_build_object(
      'available',true,
      'fecha_nacimiento',p.fecha_nacimiento,
      'age',extract(year from age(current_date,p.fecha_nacimiento))::integer,
      'age_16_plus',extract(year from age(current_date,p.fecha_nacimiento))>=16,
      'age_18_plus',extract(year from age(current_date,p.fecha_nacimiento))>=18
    )
  end
  from (select auth.uid() as uid) x
  left join public.kombax_account_private_r117 p on p.perfil_id=x.uid;
$$;
revoke all on function public.app_kombax_account_age_context_r117() from public,anon;
grant execute on function public.app_kombax_account_age_context_r117() to authenticated;

-- Professional/Spectator profile creation reuses signup DOB when the UI does not resend it.
do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_perfil_mutate_v196' and p.prokind='f';
  d:=replace(
    d,
    'if v_dob is null and v_id is not null then select p.fecha_nacimiento into v_dob from public.kombax_perfil_persona_privada_v196 p where p.perfil_directo_id=v_id;end if;',
    'if v_dob is null and v_id is not null then select p.fecha_nacimiento into v_dob from public.kombax_perfil_persona_privada_v196 p where p.perfil_directo_id=v_id;end if;' ||
    chr(10) ||
    '    if v_dob is null then select a.fecha_nacimiento into v_dob from public.kombax_account_private_r117 a where a.perfil_id=v_uid;end if;'
  );
  execute d;
end $$;

notify pgrst,'reload schema';
