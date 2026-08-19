-- KOMBAX LOAD FIXTURE · 50 CLUBES · SOLO LOCAL/QA
-- NO EJECUTAR EN PRODUCCIÓN. Requiere habilitación manual de sesión:
--   set app.kombax_load_fixture_enabled = 'on';
-- Volumen nominal: 50 clubes, 150 disciplinas, 200 grupos,
-- 2000 socios, 5600 sesiones, 56000 asistencias,
-- 1000 notificaciones y 12000 cuotas.

begin;
do $guard$
begin
  if coalesce(current_setting('app.kombax_load_fixture_enabled',true),'off')<>'on' then
    raise exception 'KOMBAX_LOAD_FIXTURE_BLOCKED: habilita solo en una base local/QA desechable';
  end if;
end
$guard$;

do $fixture$
declare
  v_total integer:=50;v_i integer;v_d integer;v_g integer;v_m integer;v_s integer;v_a integer;v_month integer;
  v_club uuid;v_disc uuid;v_group uuid;v_member uuid;v_session uuid;
begin
  for v_i in 1..v_total loop
    v_club:=(md5('kombax-load-club-'||v_i))::uuid;
    insert into public.clubes(id,nombre,slug,lema,activo,color_primario,color_secundario)
    values(v_club,'KOMBAX Load Club '||lpad(v_i::text,3,'0'),'kombax-load-'||lpad(v_i::text,3,'0'),'DATOS SINTÉTICOS · NO REAL',true,'#F7F7F5','#090A0C') on conflict(id) do nothing;

    for v_d in 1..3 loop
      v_disc:=(md5('kombax-load-discipline-'||v_i||'-'||v_d))::uuid;
      insert into public.disciplinas(id,club_id,nombre,descripcion,activa,orden)
      values(v_disc,v_club,(array['Boxeo','Muay Thai','Grappling'])[v_d],'Disciplina sintética para pruebas de carga',true,v_d) on conflict(id) do nothing;
    end loop;

    for v_g in 1..4 loop
      v_disc:=(md5('kombax-load-discipline-'||v_i||'-'||(((v_g-1)%3)+1)))::uuid;
      v_group:=(md5('kombax-load-group-'||v_i||'-'||v_g))::uuid;
      insert into public.grupos(id,club_id,disciplina_id,nombre,monitor_nombre,sala,plazas,activo)
      values(v_group,v_club,v_disc,'Grupo sintético '||v_g,'Monitor QA','Sala '||v_g,40,true) on conflict(id) do nothing;
    end loop;

    for v_m in 1..40 loop
      v_member:=(md5('kombax-load-member-'||v_i||'-'||v_m))::uuid;
      insert into public.socios(id,club_id,nombre,apellidos,fecha_nacimiento,estado,fecha_alta)
      values(v_member,v_club,'Alumno '||lpad(v_m::text,3,'0'),'Carga '||lpad(v_i::text,3,'0'),date '1990-01-01'+(v_m%500), 'activo',date '2026-01-01') on conflict(id) do nothing;
      for v_month in 1..6 loop
        insert into public.cuotas(id,club_id,socio_id,periodo,concepto,importe,vencimiento,estado)
        values((md5('kombax-load-fee-'||v_i||'-'||v_m||'-'||v_month))::uuid,v_club,v_member,(date '2026-01-01'+((v_month-1)||' months')::interval)::date,'Cuota sintética',50,(date '2026-01-10'+((v_month-1)||' months')::interval)::date,case when v_month<4 then 'pagada'::public.estado_cuota else 'pendiente'::public.estado_cuota end) on conflict(id) do nothing;
      end loop;
    end loop;

    for v_g in 1..4 loop
      v_group:=(md5('kombax-load-group-'||v_i||'-'||v_g))::uuid;
      for v_s in 1..28 loop
        v_session:=(md5('kombax-load-session-'||v_i||'-'||v_g||'-'||v_s))::uuid;
        insert into public.sesiones_entrenamiento(id,club_id,grupo_id,fecha,hora_inicio,hora_fin,monitor_nombre,estado)
        values(v_session,v_club,v_group,date '2026-09-01'+(v_s-1),time '18:00',time '19:30','Monitor QA',case when v_s<15 then 'completada' else 'programada' end) on conflict(id) do nothing;
        for v_a in 1..10 loop
          v_member:=(md5('kombax-load-member-'||v_i||'-'||(((v_g-1)*10)+v_a)))::uuid;
          insert into public.asistencias(id,club_id,sesion_id,socio_id,estado)
          values((md5('kombax-load-attendance-'||v_i||'-'||v_g||'-'||v_s||'-'||v_a))::uuid,v_club,v_session,v_member,case when v_s<15 then 'presente'::public.estado_asistencia else 'pendiente'::public.estado_asistencia end) on conflict(id) do nothing;
        end loop;
      end loop;
    end loop;

    for v_s in 1..20 loop
      insert into public.notificaciones(id,club_id,audiencia,tipo,titulo,cuerpo,datos,creado_en)
      values((md5('kombax-load-notification-'||v_i||'-'||v_s))::uuid,v_club,'todos',case when v_s%2=0 then 'sesiones' else 'comunicacion' end,'Aviso sintético '||v_s,'Contenido QA sin destinatario real',jsonb_build_object('fixture',true),timestamptz '2026-09-01 10:00:00+00'+((v_s-1)||' hours')::interval) on conflict(id) do nothing;
    end loop;
  end loop;
end
$fixture$;

commit;
