-- Execute ONLY after frontend build 20.098 or later is deployed.
-- Enables Urban Warriors as a controlled pilot organizer without changing Club Basic globally.
insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen,inicia_en,asignada_por)
select 'club',c.id,'events.public.organize',true,'promocion',now(),null
from public.clubes c
where c.slug='urban-warriors' and c.activo
  and not exists(
    select 1 from public.kombax_entitlements e
    where e.sujeto_tipo='club' and e.sujeto_id=c.id and e.capacidad_clave='events.public.organize' and e.activa
  );
