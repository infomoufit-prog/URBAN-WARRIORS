begin;
create or replace function public.app_club_titular_coordination_fix16()
returns trigger language plpgsql set search_path='' as $$
begin
 if new.rol='direccion' then new.coordinacion:=false; end if;
 return new;
end $$;
revoke all on function public.app_club_titular_coordination_fix16() from public,anon,authenticated;
create trigger club_titular_coordination_fix16 before insert or update of rol,coordinacion
on public.miembros_club for each row execute function public.app_club_titular_coordination_fix16();
update public.miembros_club set coordinacion=false where rol='direccion' and coordinacion is true;
commit;
