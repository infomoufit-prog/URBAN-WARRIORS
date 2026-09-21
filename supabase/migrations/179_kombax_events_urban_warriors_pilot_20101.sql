-- KOMBAX RC13 build 20.101 R6 · Urban Warriors pilot Events organizer entitlement
-- Data-only, idempotent pilot activation. Does not grant other clubs/federations access.
begin;

do $$
declare
  v_club_id uuid;
begin
  select c.id into v_club_id
  from public.clubes c
  where c.activo and lower(trim(c.nombre))='urban warriors'
  order by c.id
  limit 1;

  if v_club_id is null then
    raise exception 'KOMBAX_URBAN_WARRIORS_CLUB_NOT_FOUND';
  end if;

  update public.kombax_entitlements e
     set activa=true,
         origen='promocion',
         inicia_en=least(e.inicia_en,now()),
         termina_en=null
   where e.sujeto_tipo='club'
     and e.sujeto_id=v_club_id
     and e.capacidad_clave='events.public.organize';

  if not found then
    insert into public.kombax_entitlements(
      sujeto_tipo,sujeto_id,capacidad_clave,activa,origen,inicia_en,termina_en
    ) values(
      'club',v_club_id,'events.public.organize',true,'promocion',now(),null
    );
  end if;
end $$;

commit;
