-- Fija el tipo de cuenta desde el alta. Las cuentas previas se fijan en su
-- primera solicitud nueva, conservando sus perfiles piloto actuales.
begin;

create table if not exists public.kombax_account_types_r100 (
  user_id uuid primary key references auth.users(id) on delete cascade,
  account_type text not null check(account_type in
    ('club','miembro','competidor','marca','federacion','profesional','media')),
  selected_at timestamptz not null default now()
);
alter table public.kombax_account_types_r100 enable row level security;
revoke all on public.kombax_account_types_r100 from public,anon,authenticated;

create or replace function public.app_kombax_account_type_on_signup_r100()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_type text:=lower(btrim(coalesce(new.raw_user_meta_data->>'kombax_account_type','')));
begin
  if v_type in ('club','competidor','marca','federacion','profesional','media') then
    insert into public.kombax_account_types_r100(user_id,account_type)
    values(new.id,v_type) on conflict(user_id) do nothing;
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_account_type_on_signup_r100() from public,anon,authenticated;
drop trigger if exists kombax_account_type_on_signup_r100 on auth.users;
create trigger kombax_account_type_on_signup_r100 after insert on auth.users
for each row execute function public.app_kombax_account_type_on_signup_r100();

create or replace function public.app_kombax_account_type_lock_r100()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=new.perfil_id;
  v_type text:=new.tipo;
  v_member boolean;
  v_club_admin boolean;
  v_intended text;
  v_locked text;
begin
  if v_type='espectador' then return new; end if;
  select exists(select 1 from public.miembros_club m where m.perfil_id=v_uid
                and m.activo and (m.rol='direccion' or m.coordinacion)) into v_club_admin;
  select exists(select 1 from public.identidades_sociales i where i.perfil_id=v_uid
                and i.estado='activa') into v_member;
  v_intended:=case when v_club_admin then 'club'
                   when v_member and v_type='competidor' then 'miembro'
                   else v_type end;
  insert into public.kombax_account_types_r100(user_id,account_type)
  values(v_uid,v_intended) on conflict(user_id) do nothing;
  select account_type into v_locked from public.kombax_account_types_r100
  where user_id=v_uid for update;
  if v_locked<>v_type and not (v_locked='miembro' and v_type='competidor') then
    raise exception 'KOMBAX_ACCOUNT_TYPE_IMMUTABLE';
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_account_type_lock_r100() from public,anon,authenticated;

drop trigger if exists a_kombax_direct_account_lock_r100 on public.perfiles_kombax_directos;
create trigger a_kombax_direct_account_lock_r100 before insert
on public.perfiles_kombax_directos for each row execute function public.app_kombax_account_type_lock_r100();
drop trigger if exists a_kombax_application_account_lock_r100 on public.kombax_solicitudes_alta;
create trigger a_kombax_application_account_lock_r100 before insert
on public.kombax_solicitudes_alta for each row execute function public.app_kombax_account_type_lock_r100();

commit;
