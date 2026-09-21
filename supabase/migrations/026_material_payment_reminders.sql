-- 026_material_payment_reminders.sql
-- Integra material en el motor financiero existente sin crear otro recordatorio.

begin;

do $migration$
begin
  if to_regprocedure('public.procesar_avisos_cobro_pre_material_026(date,uuid)') is null then
    if to_regprocedure('public.procesar_avisos_cobro(date,uuid)') is null then raise exception '026: falta motor de avisos RC10'; end if;
    alter function public.procesar_avisos_cobro(date,uuid) rename to procesar_avisos_cobro_pre_material_026;
  end if;
end
$migration$;
revoke all on function public.procesar_avisos_cobro_pre_material_026(date,uuid) from public,anon,authenticated;

create or replace function public.procesar_avisos_cobro(
  p_fecha date default current_date,
  p_club_id uuid default null
) returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_club record;
  v_numero smallint;
  v_generados integer:=0;
  v_vencidas integer:=0;
  v_generados_club integer:=0;
  v_vencidas_club integer:=0;
begin
  for v_club in
    select c.id,c.nombre,coalesce(cfg.dias_aviso,array[1,4,8,11,14]::smallint[]) dias_aviso,
      coalesce(cfg.activo,true) activo,coalesce(cfg.marcar_vencida_dia,15) dia_vencida,
      coalesce(cfg.agrupar_por_familia,true) agrupar_por_familia
    from public.clubes c
    left join public.configuracion_avisos_cuota cfg on cfg.club_id=c.id
    where c.activo and (p_club_id is null or c.id=p_club_id)
  loop
    if not v_club.activo then continue; end if;

    update public.cuotas set
      avisos_pausados=false,avisos_pausados_hasta=null,motivo_pausa_avisos=null,
      avisos_pausados_por=null,avisos_pausados_en=null,actualizado_en=now()
    where club_id=v_club.id and avisos_pausados and avisos_pausados_hasta is not null
      and avisos_pausados_hasta<p_fecha and estado not in ('pagada','anulada','exenta');

    v_numero:=array_position(v_club.dias_aviso,extract(day from p_fecha)::smallint);
    if v_numero is not null then
      with pendientes as(
        select q.id cuota_id,q.club_id,q.socio_id,q.importe,q.periodo,q.vencimiento,q.origen,
          coalesce(q.concepto_publico,q.concepto) concepto,
          coalesce(s.perfil_id,t.tutor_perfil_id) perfil_id,
          trim(concat_ws(' ',s.nombre,s.apellidos)) alumno,
          case when v_club.agrupar_por_familia then coalesce(s.perfil_id,t.tutor_perfil_id)::text else q.id::text end grupo_clave,
          greatest(q.importe-coalesce((select sum(p.importe) from public.pagos p where p.cuota_id=q.id and p.estado_validacion='validado'),0),0) saldo
        from public.cuotas q
        join public.socios s on s.club_id=q.club_id and s.id=q.socio_id
        left join lateral(
          select ts.tutor_perfil_id from public.tutores_socios ts
          where ts.club_id=s.club_id and ts.socio_id=s.id and ts.contacto_principal order by ts.id limit 1
        ) t on true
        where q.club_id=v_club.id
          and q.estado in ('pendiente','parcialmente_pagada','vencida')
          and not q.avisos_pausados
          and (q.avisos_pausados_hasta is null or q.avisos_pausados_hasta<p_fecha)
      ),agrupadas as(
        select perfil_id,club_id,grupo_clave,sum(saldo) total,count(*) conceptos_count,
          bool_and(origen='material') solo_material,min(concepto) concepto_unico,
          array_agg(cuota_id) cuotas
        from pendientes where perfil_id is not null and saldo>0
        group by perfil_id,club_id,grupo_clave
      ),notifs as(
        insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos)
        select club_id,perfil_id,
          'cobro-'||to_char(p_fecha,'YYYY-MM')||'-aviso-'||v_numero||'-'||perfil_id||'-'||grupo_clave,
          'aviso_cobro',
          case when conceptos_count=1 and solo_material then 'Material pendiente'
            when v_numero=5 then 'Último recordatorio de pago' else 'Pago pendiente' end,
          case
            when conceptos_count=1 and solo_material then concepto_unico||' — '||to_char(total,'FM999999990.00')||' €.'
            when conceptos_count>1 then 'Tienes '||conceptos_count||' conceptos pendientes por un total de '||to_char(total,'FM999999990.00')||' €.'
            else concepto_unico||' — '||to_char(total,'FM999999990.00')||' € pendiente.'
          end,
          'fees',jsonb_build_object('aviso_numero',v_numero,'cuotas',cuotas,'total',total,'conceptos',conceptos_count)
        from agrupadas
        on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing
        returning id,club_id,perfil_id,datos
      ),history as(
        insert into public.historial_avisos_cuota(
          club_id,cuota_id,perfil_id,aviso_numero,fecha_programada,canal,estado,notificacion_id,enviado_en
        )
        select n.club_id,(jsonb_array_elements_text(n.datos->'cuotas'))::uuid,n.perfil_id,v_numero,p_fecha,'app','enviado',n.id,now()
        from notifs n
        on conflict(club_id,cuota_id,perfil_id,aviso_numero,canal) do nothing
        returning 1
      ) select count(*) into v_generados_club from history;
      v_generados:=v_generados+coalesce(v_generados_club,0);
    end if;

    if extract(day from p_fecha)::smallint>=v_club.dia_vencida then
      with upd as(
        update public.cuotas q set estado='vencida',actualizado_en=now()
        where q.club_id=v_club.id and q.estado in ('pendiente','parcialmente_pagada') and not q.avisos_pausados
        returning 1
      ) select count(*) into v_vencidas_club from upd;
      v_vencidas:=v_vencidas+coalesce(v_vencidas_club,0);
      if v_vencidas_club>0 then
        insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos)
        select v_club.id,rol,'vencidas-'||to_char(p_fecha,'YYYY-MM')||'-'||rol::text,
          'cuota','Cargos vencidos para revisar',v_vencidas_club||' cargo(s) han pasado a vencido.',
          'fees',jsonb_build_object('cantidad',v_vencidas_club)
        from unnest(array['direccion','secretaria','economia']::public.rol_club[]) rol
        on conflict do nothing;
      end if;
    end if;
  end loop;
  return jsonb_build_object('fecha',p_fecha,'avisos_generados',v_generados,'cargos_vencidos',v_vencidas);
end
$$;

revoke all on function public.procesar_avisos_cobro(date,uuid) from public,anon,authenticated;
grant execute on function public.procesar_avisos_cobro(date,uuid) to service_role;

commit;

select to_regprocedure('public.procesar_avisos_cobro_pre_material_026(date,uuid)') is not null as rollback_ok;
