-- RC13 build 20018 · prueba transaccional 034
-- Crea dos avisos temporales para un miembro real: uno informativo y uno
-- accionable explícito. Verifica que la lectura masiva solo limpia el primero,
-- que la lectura simple rechaza el accionable y que "revisar" sí lo marca.
-- Todo el dato de prueba se revierte al finalizar correctamente.

do $test$
declare
  v_club uuid;
  v_perfil uuid;
  v_info uuid:=gen_random_uuid();
  v_action uuid:=gen_random_uuid();
  v_info_group uuid:=gen_random_uuid();
  v_action_group uuid:=gen_random_uuid();
  v_failed boolean:=false;
  v_result jsonb;
begin
  select m.club_id,m.perfil_id into v_club,v_perfil
  from public.miembros_club m
  where m.activo and m.perfil_id is not null
  order by m.creado_en,m.perfil_id
  limit 1;
  if v_club is null or v_perfil is null then
    raise exception '034 TEST: no existe un miembro activo para ejecutar la prueba';
  end if;

  begin
    perform set_config('request.jwt.claim.sub',v_perfil::text,true);

    insert into public.notificaciones(id,club_id,perfil_id,tipo,titulo,cuerpo,ruta,datos,leida)
    values
      (v_info,v_club,v_perfil,'sistema','UW TEST 034 informativa','Debe admitir lectura masiva','dashboard','{"requiere_accion":false}'::jsonb,false),
      (v_action,v_club,v_perfil,'sistema','UW TEST 034 accionable','Debe exigir revisión','dashboard','{"requiere_accion":true}'::jsonb,false);

    v_result:=public.app_mutate_v160('notificacion.leer_todas',jsonb_build_object('club_id',v_club),gen_random_uuid());

    if not exists(select 1 from public.notificaciones where id=v_info and leida) then
      raise exception '034 TEST: la informativa no quedó leída tras lectura masiva';
    end if;
    if exists(select 1 from public.notificaciones where id=v_action and leida) then
      raise exception '034 TEST: la accionable fue ocultada por lectura masiva';
    end if;
    if coalesce((v_result->'data'->>'accionables_conservadas')::integer,0)<1 then
      raise exception '034 TEST: el resultado no informa de la tarea accionable conservada';
    end if;

    insert into public.notificaciones(id,club_id,perfil_id,tipo,titulo,cuerpo,ruta,datos,leida)
    values
      (v_info_group,v_club,v_perfil,'evento','UW TEST 034 grupo informativo','La lectura de grupo debe limpiarlo','events','{"requiere_accion":false}'::jsonb,false),
      (v_action_group,v_club,v_perfil,'evento','UW TEST 034 grupo accionable','La lectura de grupo debe conservarlo','events','{"requiere_accion":true}'::jsonb,false);
    perform public.app_mutate_v160('notificacion.leer_grupo',jsonb_build_object('club_id',v_club,'tipo','evento'),gen_random_uuid());
    if not exists(select 1 from public.notificaciones where id=v_info_group and leida) then
      raise exception '034 TEST: la lectura por grupo no limpió la informativa';
    end if;
    if exists(select 1 from public.notificaciones where id=v_action_group and leida) then
      raise exception '034 TEST: la lectura por grupo ocultó una tarea accionable';
    end if;

    begin
      perform public.app_mutate_v160('notificacion.leer',jsonb_build_object('club_id',v_club,'notificacion_id',v_action),gen_random_uuid());
    exception when others then
      if position('requiere revisión' in sqlerrm)>0 then v_failed:=true; else raise; end if;
    end;
    if not v_failed then raise exception '034 TEST: lectura individual simple permitió una tarea accionable'; end if;

    perform public.app_mutate_v160('notificacion.revisar',jsonb_build_object('club_id',v_club,'notificacion_id',v_action),gen_random_uuid());
    if not exists(select 1 from public.notificaciones where id=v_action and leida) then
      raise exception '034 TEST: revisar no marcó la tarea como leída';
    end if;
    if not exists(select 1 from public.notificaciones_revisiones where notificacion_id=v_action and perfil_id=v_perfil) then
      raise exception '034 TEST: revisar no dejó trazabilidad';
    end if;

    -- Fuerza rollback de este subbloque para no dejar filas de prueba.
    raise exception 'UW_034_TEST_ROLLBACK_OK';
  exception when others then
    if sqlerrm<>'UW_034_TEST_ROLLBACK_OK' then raise; end if;
  end;

  raise notice '034 TEST OK: lectura global y por grupo limpian informativas; accionables solo mediante revisión; datos de prueba revertidos.';
end
$test$;
