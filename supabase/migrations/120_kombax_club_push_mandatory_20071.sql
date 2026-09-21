-- KOMBAX RC13 build 20071 · 120
-- Los push de Mi club son avisos operativos del club y no son configurables
-- por categoría por el usuario. El permiso global del sistema operativo sigue
-- siendo soberano; esta regla solo evita opt-out parciales dentro de KOMBAX.
begin;

update public.preferencias_notificacion
set push_general=true,
    push_finanzas=true,
    push_sesiones=true,
    push_comunidad=true,
    actualizado_en=now()
where not (push_general and push_finanzas and push_sesiones and push_comunidad);

create or replace function public.kombax_force_mi_club_push_mandatory_v120()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  new.push_general:=true;
  new.push_finanzas:=true;
  new.push_sesiones:=true;
  new.push_comunidad:=true;
  new.actualizado_en:=now();
  return new;
end $$;

drop trigger if exists trg_kombax_force_mi_club_push_mandatory_v120 on public.preferencias_notificacion;
create trigger trg_kombax_force_mi_club_push_mandatory_v120
before insert or update of push_general,push_finanzas,push_sesiones,push_comunidad
on public.preferencias_notificacion
for each row execute function public.kombax_force_mi_club_push_mandatory_v120();

comment on function public.kombax_force_mi_club_push_mandatory_v120() is
'Mi club: fuerza las cuatro categorías push a TRUE. El usuario no dispone de opt-out por categoría dentro de KOMBAX.';

notify pgrst,'reload schema';
commit;
