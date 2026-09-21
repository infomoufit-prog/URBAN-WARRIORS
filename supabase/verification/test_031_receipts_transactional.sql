-- Prueba transaccional: crea cargos temporales, valida recibos y revierte todo.
-- Ejecutar solo después de aplicar 031. No deja cuotas, recibos ni notificaciones.

begin;

create temporary table uw_v031_results(
  orden integer,
  control text,
  estado text,
  detalle text
) on commit drop;

do $$
declare
  v_club uuid;
  v_socio uuid;
  v_cuota uuid;
  v_material uuid;
  v_parcial uuid;
  v_origen_id uuid:=gen_random_uuid();
begin
  select s.club_id,s.id into v_club,v_socio
  from public.socios s
  order by s.creado_en,s.id
  limit 1;
  if v_socio is null then raise exception 'Se necesita al menos un socio para la prueba transaccional'; end if;

  insert into public.cuotas(club_id,socio_id,periodo,concepto,concepto_publico,importe,vencimiento,estado,origen)
  values(v_club,v_socio,date_trunc('month',current_date)::date,'TEST RC12 CUOTA','TEST RC12 CUOTA',41.25,current_date,'pendiente','cuota')
  returning id into v_cuota;
  update public.cuotas set estado='pagada' where id=v_cuota;

  insert into public.cuotas(club_id,socio_id,periodo,concepto,concepto_publico,importe,vencimiento,estado,origen,origen_id)
  values(v_club,v_socio,date_trunc('month',current_date)::date,'Material: TEST RC12 [00000000]','Material: TEST RC12',27.50,current_date,'pendiente','material',v_origen_id)
  returning id into v_material;
  update public.cuotas set estado='pagada' where id=v_material;

  insert into public.cuotas(club_id,socio_id,periodo,concepto,concepto_publico,importe,vencimiento,estado,origen)
  values(v_club,v_socio,date_trunc('month',current_date)::date,'TEST RC12 PARCIAL','TEST RC12 PARCIAL',80,current_date,'pendiente','cuota')
  returning id into v_parcial;
  update public.cuotas set estado='parcialmente_pagada' where id=v_parcial;

  insert into uw_v031_results
  select 1,'cuota pagada emite recibo',case when count(*)=1 then 'OK' else 'FALLO' end,count(*)::text
  from public.recibos_cuota where cuota_id=v_cuota;

  insert into uw_v031_results
  select 2,'material pagado emite recibo',case when count(*)=1 then 'OK' else 'FALLO' end,count(*)::text
  from public.recibos_cuota where cuota_id=v_material and origen='material';

  insert into uw_v031_results
  select 3,'importe recibo cuota',case when importe=41.25 then 'OK' else 'FALLO' end,importe::text
  from public.recibos_cuota where cuota_id=v_cuota;

  insert into uw_v031_results
  select 4,'importe recibo material',case when importe=27.50 then 'OK' else 'FALLO' end,importe::text
  from public.recibos_cuota where cuota_id=v_material;

  insert into uw_v031_results
  select 5,'concepto material visible',case when concepto='Material: TEST RC12' and actividad='Material: TEST RC12' then 'OK' else 'FALLO' end,
    coalesce(concepto,'NULL')||' / '||coalesce(actividad,'NULL')
  from public.recibos_cuota where cuota_id=v_material;

  insert into uw_v031_results
  select 6,'pago parcial sin recibo final',case when count(*)=0 then 'OK' else 'FALLO' end,count(*)::text
  from public.recibos_cuota where cuota_id=v_parcial;

  insert into uw_v031_results
  select 7,'un recibo por cargo',case when count(*)=2 then 'OK' else 'FALLO' end,count(*)::text
  from public.recibos_cuota where cuota_id in(v_cuota,v_material,v_parcial);
end $$;

select control,estado,detalle from uw_v031_results order by orden;

rollback;
