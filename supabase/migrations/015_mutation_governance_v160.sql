-- ============================================================================
-- URBAN WARRIORS 1.6.0 — GOBERNANZA ÚNICA DE ESCRITURAS
-- Ejecutar DESPUÉS de 014_autotest_notification_fix_v152.sql.
--
-- Objetivo:
--   * Una única puerta REST/PostgREST para TODAS las mutaciones de la web/APK.
--   * Contrato de backend versionado y verificable antes de guardar.
--   * Idempotencia por request_id: un reintento de red no duplica escrituras.
--   * Cero dependencias del frontend respecto a RPC históricas 007/008/009/010/012.
--   * Las RPC históricas quedan encapsuladas en servidor, donde sus firmas son
--     resueltas por PostgreSQL con tipos explícitos y no por PostgREST.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. METADATOS DE CONTRATO + REGISTRO DE IDEMPOTENCIA
-- ---------------------------------------------------------------------------
create table if not exists public.app_runtime_meta (
  singleton boolean primary key default true check (singleton),
  backend_version text not null,
  schema_epoch integer not null,
  mutation_endpoint text not null,
  updated_at timestamptz not null default now()
);

insert into public.app_runtime_meta(singleton,backend_version,schema_epoch,mutation_endpoint,updated_at)
values(true,'1.6.0',160,'app_mutate_v160',now())
on conflict(singleton) do update set
  backend_version=excluded.backend_version,
  schema_epoch=excluded.schema_epoch,
  mutation_endpoint=excluded.mutation_endpoint,
  updated_at=excluded.updated_at;

revoke all on table public.app_runtime_meta from public,anon,authenticated;

create table if not exists public.app_mutation_requests (
  request_id uuid primary key,
  user_id uuid not null,
  club_id uuid,
  operation text not null,
  result jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create index if not exists app_mutation_requests_user_created
  on public.app_mutation_requests(user_id,created_at desc);
alter table public.app_mutation_requests enable row level security;
revoke all on table public.app_mutation_requests from public,anon,authenticated;

-- Limpieza preventiva: conservar solo 30 días de claves de idempotencia.
-- No se programa cron aquí; la propia puerta elimina únicamente registros antiguos
-- del usuario actual y nunca toca datos funcionales del gimnasio.

-- ---------------------------------------------------------------------------
-- 1. CONTRATO DE RUNTIME. La app NO habilita guardar si este contrato no coincide.
-- ---------------------------------------------------------------------------
create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare
  v_uid uuid := auth.uid();
  v_roles jsonb;
  v_meta public.app_runtime_meta;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if not public.es_miembro_club(p_club_id) then
    raise exception 'CLUB_MEMBERSHIP_REQUIRED: la cuenta no pertenece al club activo';
  end if;
  select * into v_meta from public.app_runtime_meta where singleton=true;
  if v_meta.singleton is null then raise exception 'BACKEND_META_MISSING'; end if;
  select coalesce(jsonb_agg(m.rol order by m.rol::text),'[]'::jsonb)
    into v_roles
    from public.miembros_club m
   where m.club_id=p_club_id and m.perfil_id=v_uid and m.activo;
  return jsonb_build_object(
    'ok',true,
    'backend_version',v_meta.backend_version,
    'schema_epoch',v_meta.schema_epoch,
    'mutation_endpoint',v_meta.mutation_endpoint,
    'club_id',p_club_id,
    'user_id',v_uid,
    'roles',v_roles,
    'write_ready',true,
    'operations',jsonb_build_array(
      'cuenta.registrar','invitacion.aceptar','invitacion.crear','perfil.guardar','disciplina.guardar','grado.guardar','grupo.guardar',
      'alumno.guardar','preinscripcion.crear','preinscripcion.aprobar','preinscripcion.espera','preinscripcion.rechazar',
      'matricula.solicitar','matricula.desactivar','graduacion.registrar','tarifa.guardar','material.guardar',
      'material.variante.guardar','material.solicitar','material.pedido.estado','publicacion.guardar','sesion.guardar',
      'asistencia.guardar','checkin.registrar','seguimiento.guardar','documento.registrar','notificacion.leer',
      'pago.comunicar','pago.registrar_admin','pago.validar','cuota.pausar_avisos','cuota.reactivar_avisos',
      'avisos.configurar','cuotas.generar','avisos.procesar','club.configurar','push.registrar'
    )
  );
end; $$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. PUERTA ÚNICA DE MUTACIÓN.
-- ---------------------------------------------------------------------------
create or replace function public.app_mutate_v160(
  p_operation text,
  p_payload jsonb,
  p_request_id uuid
) returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid := auth.uid();
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
  v_club_id uuid;
  v_existing public.app_mutation_requests;
  v_result jsonb;
  v_id uuid;
  v_int integer;
  v_payment public.pagos;
  v_fee public.cuotas;
  v_inv public.invitaciones_club;
  v_days smallint[];
  v_roles public.rol_club[];
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if nullif(trim(coalesce(p_operation,'')),'') is null then raise exception 'MUTATION_OPERATION_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;

  begin
    v_club_id := nullif(trim(coalesce(v_payload->>'club_id','')),'')::uuid;
  exception when invalid_text_representation then
    raise exception 'MUTATION_INVALID_CLUB_ID';
  end;

  -- Gobierno de acceso: solo dos operaciones de bootstrap pueden ejecutarse
  -- antes de pertenecer al club. Todas las demás exigen club_id + membresía.
  if p_operation not in ('cuenta.registrar','invitacion.aceptar') then
    if v_club_id is null then raise exception 'MUTATION_CLUB_REQUIRED'; end if;
    if not public.es_miembro_club(v_club_id) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;
  end if;

  if p_operation not in (
    'cuenta.registrar','invitacion.aceptar','invitacion.crear','perfil.guardar','disciplina.guardar','grado.guardar','grupo.guardar',
    'alumno.guardar','preinscripcion.crear','preinscripcion.aprobar','preinscripcion.espera','preinscripcion.rechazar',
    'matricula.solicitar','matricula.desactivar','graduacion.registrar','tarifa.guardar','material.guardar','material.variante.guardar',
    'material.solicitar','material.pedido.estado','publicacion.guardar','sesion.guardar','asistencia.guardar','checkin.registrar',
    'seguimiento.guardar','documento.registrar','notificacion.leer','pago.comunicar','pago.registrar_admin','pago.validar',
    'cuota.pausar_avisos','cuota.reactivar_avisos','avisos.configurar','cuotas.generar','avisos.procesar','club.configurar','push.registrar'
  ) then
    raise exception 'MUTATION_OPERATION_NOT_ALLOWED: %',p_operation;
  end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then
      raise exception 'MUTATION_REQUEST_ID_REUSED';
    end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,v_club_id,p_operation);
  end if;

  -- Limitar crecimiento sin afectar otras cuentas.
  delete from public.app_mutation_requests
   where user_id=v_uid and created_at < now()-interval '30 days';

  case p_operation
    -- Cuenta/invitación. cuenta.registrar e invitacion.aceptar pueden ejecutarse
    -- antes de que exista una membresía en el club, pero siempre requieren auth.uid().
    when 'cuenta.registrar' then
      v_result := public.registrar_cuenta_club(
        v_payload->>'club_slug',
        v_payload->>'tipo_cuenta',
        v_payload->>'adulto_nombre',
        v_payload->>'adulto_apellidos',
        v_payload->>'telefono',
        nullif(v_payload->>'fecha_nacimiento_adulto','')::date,
        nullif(v_payload->>'menor_nombre',''),
        nullif(v_payload->>'menor_apellidos',''),
        nullif(v_payload->>'fecha_nacimiento_menor','')::date,
        nullif(v_payload->>'disciplina_id','')::uuid,
        nullif(v_payload->>'grupo_id','')::uuid,
        nullif(v_payload->>'tarifa_id','')::uuid
      );

    when 'invitacion.aceptar' then
      v_result := public.aceptar_invitacion_club((v_payload->>'token')::uuid);

    when 'invitacion.crear' then
      v_inv := public.crear_invitacion_club(
        v_club_id,
        v_payload->>'email',
        (v_payload->>'rol')::public.rol_club
      );
      v_result := to_jsonb(v_inv);

    when 'perfil.guardar' then
      v_id := public.app_guardar_perfil_propio(
        coalesce(v_payload->>'nombre',''),
        coalesce(v_payload->>'apellidos',''),
        coalesce(v_payload->>'telefono','')
      );
      v_result := jsonb_build_object('id',v_id);

    when 'disciplina.guardar' then
      v_id := public.app_guardar_disciplina(
        v_club_id,
        nullif(v_payload->>'id','')::uuid,
        v_payload->>'nombre',
        coalesce(v_payload->>'descripcion',''),
        coalesce(nullif(v_payload->>'color',''),'#ffffff'),
        coalesce((v_payload->>'activa')::boolean,true),
        coalesce(nullif(v_payload->>'orden','')::smallint,0::smallint)
      );
      v_result := jsonb_build_object('id',v_id);

    when 'grado.guardar' then
      v_id := public.app_guardar_grado(
        v_club_id,
        nullif(v_payload->>'id','')::uuid,
        (v_payload->>'disciplina_id')::uuid,
        v_payload->>'nombre',
        coalesce(nullif(v_payload->>'orden','')::smallint,1::smallint),
        nullif(v_payload->>'color',''),
        nullif(v_payload->>'meses_minimos','')::smallint,
        coalesce((v_payload->>'activo')::boolean,true)
      );
      v_result := jsonb_build_object('id',v_id);

    when 'grupo.guardar' then
      v_id := public.app_guardar_grupo(
        v_club_id,
        nullif(v_payload->>'id','')::uuid,
        (v_payload->>'disciplina_id')::uuid,
        v_payload->>'nombre',
        coalesce(v_payload->>'monitor_nombre',''),
        coalesce(v_payload->>'sala',''),
        nullif(v_payload->>'edad_min','')::smallint,
        nullif(v_payload->>'edad_max','')::smallint,
        nullif(v_payload->>'plazas','')::integer,
        coalesce((v_payload->>'activo')::boolean,true),
        coalesce(v_payload->'horarios','[]'::jsonb)
      );
      v_result := jsonb_build_object('id',v_id);

    when 'alumno.guardar' then
      v_id := public.app_guardar_socio(
        v_club_id,
        nullif(v_payload->>'id','')::uuid,
        v_payload->>'nombre',
        v_payload->>'apellidos',
        nullif(v_payload->>'fecha_nacimiento','')::date,
        coalesce(v_payload->>'telefono',''),
        coalesce(v_payload->>'email',''),
        coalesce(v_payload->>'tutor_nombre',''),
        nullif(v_payload->>'disciplina_id','')::uuid,
        nullif(v_payload->>'grupo_id','')::uuid,
        nullif(v_payload->>'grado_id','')::uuid,
        coalesce(v_payload->>'grado_texto',''),
        nullif(v_payload->>'tarifa_id','')::uuid,
        coalesce(nullif(v_payload->>'estado',''),'activo'),
        coalesce(v_payload->>'contacto_emergencia',''),
        coalesce(v_payload->>'telefono_emergencia',''),
        coalesce(v_payload->>'notas_internas','')
      );
      v_result := jsonb_build_object('id',v_id);

    when 'preinscripcion.crear' then
      v_id := public.app_crear_preinscripcion(
        v_club_id,
        coalesce(nullif(v_payload->>'tipo_solicitud',''),'adulto'),
        v_payload->>'nombre',
        v_payload->>'apellidos',
        nullif(v_payload->>'fecha_nacimiento','')::date,
        coalesce(v_payload->>'tutor_nombre',''),
        coalesce(v_payload->>'tutor_email',''),
        coalesce(v_payload->>'telefono',''),
        nullif(v_payload->>'disciplina_id','')::uuid,
        nullif(v_payload->>'grupo_id','')::uuid,
        nullif(v_payload->>'tarifa_id','')::uuid,
        nullif(v_payload->>'parentesco',''),
        nullif(v_payload->>'observaciones','')
      );
      v_result := jsonb_build_object('id',v_id);

    when 'preinscripcion.aprobar' then
      v_id := public.app_aprobar_preinscripcion((v_payload->>'preinscripcion_id')::uuid);
      v_result := jsonb_build_object('id',v_id);

    when 'preinscripcion.espera' then
      perform public.app_lista_espera_preinscripcion(
        (v_payload->>'preinscripcion_id')::uuid,
        nullif(v_payload->>'motivo','')
      );
      v_result := jsonb_build_object('ok',true);

    when 'preinscripcion.rechazar' then
      perform public.app_rechazar_preinscripcion(
        (v_payload->>'preinscripcion_id')::uuid,
        coalesce(v_payload->>'motivo','')
      );
      v_result := jsonb_build_object('ok',true);

    when 'matricula.solicitar' then
      v_id := public.app_solicitar_nueva_matricula(
        (v_payload->>'socio_id')::uuid,
        (v_payload->>'disciplina_id')::uuid,
        (v_payload->>'grupo_id')::uuid,
        nullif(v_payload->>'tarifa_id','')::uuid
      );
      v_result := jsonb_build_object('id',v_id);

    when 'matricula.desactivar' then
      v_id := public.app_desactivar_matricula((v_payload->>'matricula_id')::uuid);
      v_result := jsonb_build_object('id',v_id);

    when 'graduacion.registrar' then
      v_id := public.app_registrar_graduacion(
        v_club_id,
        (v_payload->>'socio_id')::uuid,
        (v_payload->>'disciplina_id')::uuid,
        (v_payload->>'grado_id')::uuid,
        nullif(v_payload->>'fecha','')::date,
        coalesce(v_payload->>'examinador',''),
        coalesce(v_payload->>'nota','')
      );
      v_result := jsonb_build_object('id',v_id);

    when 'tarifa.guardar' then
      v_id := public.app_guardar_tarifa(
        v_club_id,
        nullif(v_payload->>'id','')::uuid,
        v_payload->>'nombre',
        coalesce(v_payload->>'descripcion',''),
        coalesce(nullif(v_payload->>'importe','')::numeric,0),
        coalesce(nullif(v_payload->>'matricula','')::numeric,0),
        coalesce(nullif(v_payload->>'periodicidad',''),'mensual'),
        coalesce((v_payload->>'activa')::boolean,true)
      );
      v_result := jsonb_build_object('id',v_id);

    when 'material.guardar' then
      v_id := public.app_guardar_material(
        v_club_id,
        nullif(v_payload->>'id','')::uuid,
        nullif(v_payload->>'disciplina_id','')::uuid,
        v_payload->>'nombre',
        coalesce(v_payload->>'categoria',''),
        coalesce(v_payload->>'descripcion',''),
        coalesce(v_payload->>'imagen_url',''),
        coalesce(nullif(v_payload->>'precio','')::numeric,0),
        coalesce(nullif(v_payload->>'stock','')::integer,0),
        coalesce((v_payload->>'obligatorio')::boolean,false),
        coalesce(v_payload->>'referencia',''),
        coalesce((v_payload->>'activo')::boolean,true)
      );
      v_result := jsonb_build_object('id',v_id);

    when 'material.variante.guardar' then
      v_id := public.app_guardar_variante_material(
        v_club_id,
        nullif(v_payload->>'id','')::uuid,
        (v_payload->>'material_id')::uuid,
        nullif(v_payload->>'talla',''),
        nullif(v_payload->>'color',''),
        nullif(v_payload->>'referencia',''),
        coalesce(nullif(v_payload->>'stock','')::integer,0),
        coalesce((v_payload->>'activa')::boolean,true)
      );
      v_result := jsonb_build_object('id',v_id);

    when 'material.solicitar' then
      v_id := public.app_solicitar_material(
        (v_payload->>'socio_id')::uuid,
        (v_payload->>'material_id')::uuid,
        nullif(v_payload->>'variante_id','')::uuid,
        coalesce(nullif(v_payload->>'cantidad','')::integer,1),
        nullif(v_payload->>'observaciones','')
      );
      v_result := jsonb_build_object('id',v_id);

    when 'material.pedido.estado' then
      v_id := public.app_actualizar_pedido_material(
        (v_payload->>'pedido_id')::uuid,
        v_payload->>'estado'
      );
      v_result := jsonb_build_object('id',v_id);

    when 'publicacion.guardar' then
      v_id := public.app_guardar_comunicacion(
        v_club_id,
        nullif(v_payload->>'id','')::uuid,
        coalesce(nullif(v_payload->>'tipo',''),'noticia'),
        v_payload->>'titulo',
        v_payload->>'cuerpo',
        coalesce(nullif(v_payload->>'audiencia',''),'todos'),
        coalesce(nullif(v_payload->>'estado',''),'borrador'),
        nullif(v_payload->>'evento_fecha','')::timestamptz,
        coalesce(v_payload->>'ubicacion',''),
        coalesce(v_payload->>'imagen_url','')
      );
      v_result := jsonb_build_object('id',v_id);

    when 'sesion.guardar' then
      v_id := public.app_guardar_sesion(
        v_club_id,
        nullif(v_payload->>'id','')::uuid,
        (v_payload->>'grupo_id')::uuid,
        (v_payload->>'fecha')::date,
        (v_payload->>'hora_inicio')::time,
        nullif(v_payload->>'hora_fin','')::time,
        coalesce(v_payload->>'monitor_nombre',''),
        coalesce(nullif(v_payload->>'estado',''),'programada'),
        coalesce(v_payload->>'observacion_general',''),
        coalesce(v_payload->>'codigo_acceso','')
      );
      v_result := jsonb_build_object('id',v_id);

    when 'asistencia.guardar' then
      v_id := public.app_guardar_asistencia(
        (v_payload->>'sesion_id')::uuid,
        (v_payload->>'socio_id')::uuid,
        (v_payload->>'estado')::public.estado_asistencia,
        nullif(v_payload->>'observacion','')
      );
      v_result := jsonb_build_object('id',v_id);

    when 'checkin.registrar' then
      v_id := public.app_registrar_checkin(
        (v_payload->>'sesion_id')::uuid,
        (v_payload->>'socio_id')::uuid,
        coalesce(v_payload->>'codigo',''),
        coalesce(nullif(v_payload->>'metodo',''),'codigo')
      );
      v_result := jsonb_build_object('id',v_id);

    when 'seguimiento.guardar' then
      v_id := public.app_guardar_seguimiento(
        v_club_id,
        (v_payload->>'socio_id')::uuid,
        v_payload->>'tipo',
        v_payload->>'nota',
        coalesce(nullif(v_payload->>'visibilidad',''),'equipo')::public.visibilidad_seguimiento,
        coalesce(nullif(v_payload->>'fecha','')::date,current_date)
      );
      v_result := jsonb_build_object('id',v_id);

    when 'documento.registrar' then
      v_id := public.app_registrar_documento(
        v_club_id,
        (v_payload->>'socio_id')::uuid,
        v_payload->>'nombre',
        coalesce(nullif(v_payload->>'tipo',''),'otro'),
        v_payload->>'storage_path',
        nullif(v_payload->>'mime_type',''),
        nullif(v_payload->>'tamano_bytes','')::bigint,
        coalesce((v_payload->>'visible_familia')::boolean,true)
      );
      v_result := jsonb_build_object('id',v_id);

    when 'notificacion.leer' then
      perform public.app_marcar_notificacion_leida((v_payload->>'notificacion_id')::uuid);
      v_result := jsonb_build_object('ok',true);

    when 'pago.comunicar' then
      v_payment := public.comunicar_pago_cuota(
        (v_payload->>'cuota_id')::uuid,
        (v_payload->>'importe')::numeric,
        coalesce(nullif(v_payload->>'fecha','')::date,current_date),
        v_payload->>'metodo',
        nullif(v_payload->>'referencia',''),
        nullif(v_payload->>'justificante_path',''),
        nullif(v_payload->>'observaciones','')
      );
      v_result := to_jsonb(v_payment);

    when 'pago.registrar_admin' then
      v_payment := public.registrar_cobro_cuota(
        (v_payload->>'cuota_id')::uuid,
        (v_payload->>'importe')::numeric,
        coalesce(nullif(v_payload->>'fecha','')::date,current_date),
        v_payload->>'metodo',
        nullif(v_payload->>'referencia',''),
        nullif(v_payload->>'observaciones','')
      );
      v_result := to_jsonb(v_payment);

    when 'pago.validar' then
      v_payment := public.validar_pago_cuota(
        (v_payload->>'pago_id')::uuid,
        v_payload->>'decision',
        nullif(v_payload->>'motivo','')
      );
      v_result := to_jsonb(v_payment);

    when 'cuota.pausar_avisos' then
      v_fee := public.pausar_avisos_cuota(
        (v_payload->>'cuota_id')::uuid,
        v_payload->>'motivo',
        nullif(v_payload->>'hasta','')::date
      );
      v_result := to_jsonb(v_fee);

    when 'cuota.reactivar_avisos' then
      v_fee := public.reactivar_avisos_cuota((v_payload->>'cuota_id')::uuid);
      v_result := to_jsonb(v_fee);

    when 'avisos.configurar' then
      select coalesce(array_agg(value::smallint order by ord),array[]::smallint[])
        into v_days
        from jsonb_array_elements_text(coalesce(v_payload->'dias_aviso','[]'::jsonb)) with ordinality x(value,ord);
      v_id := public.app_guardar_config_avisos(
        v_club_id,
        v_days,
        coalesce(nullif(v_payload->>'hora_envio','')::time,'10:00'::time),
        coalesce((v_payload->>'canal_app')::boolean,true),
        coalesce((v_payload->>'canal_push')::boolean,true),
        coalesce((v_payload->>'canal_email')::boolean,false),
        coalesce((v_payload->>'agrupar_por_familia')::boolean,true),
        coalesce(nullif(v_payload->>'marcar_vencida_dia','')::smallint,15::smallint),
        coalesce(nullif(v_payload->>'zona_horaria',''),'Europe/Madrid'),
        coalesce((v_payload->>'activo')::boolean,true)
      );
      v_result := jsonb_build_object('id',v_id);

    when 'cuotas.generar' then
      v_int := public.generar_cuotas_periodo(
        v_club_id,
        coalesce(nullif(v_payload->>'periodo','')::date,date_trunc('month',current_date)::date)
      );
      v_result := jsonb_build_object('creadas',v_int);

    when 'avisos.procesar' then
      v_result := public.procesar_avisos_cobro_club(
        v_club_id,
        coalesce(nullif(v_payload->>'fecha','')::date,current_date)
      );

    when 'club.configurar' then
      if not public.tiene_rol_club(v_club_id,'direccion','secretaria','economia','comunicacion') then
        raise exception 'No tienes permiso para configurar el club';
      end if;
      update public.clubes c set
        nombre=case when v_payload ? 'nombre' then nullif(v_payload->>'nombre','') else c.nombre end,
        lema=case when v_payload ? 'lema' then nullif(v_payload->>'lema','') else c.lema end,
        telefono=case when v_payload ? 'telefono' then nullif(v_payload->>'telefono','') else c.telefono end,
        email=case when v_payload ? 'email' then nullif(v_payload->>'email','') else c.email end,
        direccion=case when v_payload ? 'direccion' then nullif(v_payload->>'direccion','') else c.direccion end,
        web=case when v_payload ? 'web' then nullif(v_payload->>'web','') else c.web end,
        logo_url=case when v_payload ? 'logo_url' then nullif(v_payload->>'logo_url','') else c.logo_url end,
        portada_url=case when v_payload ? 'portada_url' then nullif(v_payload->>'portada_url','') else c.portada_url end,
        color_primario=case when v_payload ? 'color_primario' then nullif(v_payload->>'color_primario','') else c.color_primario end,
        color_secundario=case when v_payload ? 'color_secundario' then nullif(v_payload->>'color_secundario','') else c.color_secundario end,
        actualizado_en=now()
      where c.id=v_club_id;
      if v_payload ? 'dia_vencimiento' then
        insert into public.config_club(club_id,clave,valor,actualizado_por,actualizado_en)
        values(v_club_id,'dia_vencimiento',to_jsonb((v_payload->>'dia_vencimiento')::integer),v_uid,now())
        on conflict(club_id,clave) do update set valor=excluded.valor,actualizado_por=v_uid,actualizado_en=now();
      end if;
      if v_payload ? 'avisos_clase_horas' then
        insert into public.config_club(club_id,clave,valor,actualizado_por,actualizado_en)
        values(v_club_id,'avisos_clase_horas',to_jsonb((v_payload->>'avisos_clase_horas')::integer),v_uid,now())
        on conflict(club_id,clave) do update set valor=excluded.valor,actualizado_por=v_uid,actualizado_en=now();
      end if;
      select to_jsonb(c) into v_result from public.clubes c where c.id=v_club_id;

    when 'push.registrar' then
      if v_club_id is null or not public.es_miembro_club(v_club_id) then raise exception 'Club no válido'; end if;
      insert into public.dispositivos_push(club_id,perfil_id,plataforma,token,activo,ultimo_uso)
      values(v_club_id,v_uid,coalesce(nullif(v_payload->>'plataforma',''),'web'),v_payload->>'token',true,now())
      on conflict(club_id,perfil_id,token) do update set plataforma=excluded.plataforma,activo=true,ultimo_uso=now()
      returning jsonb_build_object('id',id,'activo',activo) into v_result;

    else
      raise exception 'MUTATION_OPERATION_NOT_ALLOWED: %',p_operation;
  end case;

  if v_result is null then v_result := jsonb_build_object('ok',true); end if;
  -- Sobre común que permite al cliente verificar que el servidor correcto respondió.
  v_result := jsonb_build_object(
    'ok',true,
    'backend_version','1.6.0',
    'operation',p_operation,
    'request_id',p_request_id,
    'data',v_result
  );

  update public.app_mutation_requests
     set result=v_result,completed_at=now(),club_id=coalesce(club_id,v_club_id)
   where request_id=p_request_id;
  return v_result;
end; $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. CIERRE DE RUTAS ANTIGUAS DE ESCRITURA.
-- El frontend 1.6.0 solo puede mutar mediante app_mutate_v160. Conservamos
-- SELECT para la carga de pantallas y Storage mantiene sus políticas propias.
-- Las funciones históricas siguen existiendo para que la puerta security definer
-- las encapsule, pero dejan de estar expuestas directamente a clientes web.
-- ---------------------------------------------------------------------------
revoke insert, update, delete on table
  public.clubes, public.perfiles, public.miembros_club, public.config_club,
  public.disciplinas, public.grados, public.grupos, public.horarios_grupo,
  public.socios, public.tutores_socios, public.socio_disciplinas, public.graduaciones,
  public.preinscripciones, public.tarifas, public.cuotas, public.pagos,
  public.sesiones_entrenamiento, public.asistencias, public.registros_acceso_clase,
  public.comunicaciones, public.seguimiento, public.consentimientos,
  public.material_catalogo, public.material_variantes, public.material_pedidos,
  public.notificaciones, public.notificaciones_lecturas, public.configuracion_avisos_cuota,
  public.historial_avisos_cuota, public.documentos_socios, public.invitaciones_club,
  public.dispositivos_push
from anon, authenticated;

-- RPC históricas de mutación: solo se invocan desde app_mutate_v160 (security definer).
revoke all on function public.registrar_cuenta_club(text,text,text,text,text,date,text,text,date,uuid,uuid,uuid) from public, anon, authenticated;
revoke all on function public.aceptar_invitacion_club(uuid) from public, anon, authenticated;
revoke all on function public.crear_invitacion_club(uuid,text,public.rol_club) from public, anon, authenticated;
revoke all on function public.app_guardar_perfil_propio(text,text,text) from public, anon, authenticated;
revoke all on function public.app_guardar_disciplina(uuid,uuid,text,text,text,boolean,smallint) from public, anon, authenticated;
revoke all on function public.app_guardar_grado(uuid,uuid,uuid,text,smallint,text,smallint,boolean) from public, anon, authenticated;
revoke all on function public.app_guardar_grupo(uuid,uuid,uuid,text,text,text,smallint,smallint,integer,boolean,jsonb) from public, anon, authenticated;
revoke all on function public.app_guardar_socio(uuid,uuid,text,text,date,text,text,text,uuid,uuid,uuid,text,uuid,text,text,text,text) from public, anon, authenticated;
revoke all on function public.app_crear_preinscripcion(uuid,text,text,text,date,text,text,text,uuid,uuid,uuid,text,text) from public, anon, authenticated;
revoke all on function public.app_aprobar_preinscripcion(uuid) from public, anon, authenticated;
revoke all on function public.app_lista_espera_preinscripcion(uuid,text) from public, anon, authenticated;
revoke all on function public.app_rechazar_preinscripcion(uuid,text) from public, anon, authenticated;
revoke all on function public.app_solicitar_nueva_matricula(uuid,uuid,uuid,uuid) from public, anon, authenticated;
revoke all on function public.app_desactivar_matricula(uuid) from public, anon, authenticated;
revoke all on function public.app_registrar_graduacion(uuid,uuid,uuid,uuid,date,text,text) from public, anon, authenticated;
revoke all on function public.app_guardar_tarifa(uuid,uuid,text,text,numeric,numeric,text,boolean) from public, anon, authenticated;
revoke all on function public.app_guardar_material(uuid,uuid,uuid,text,text,text,text,numeric,integer,boolean,text,boolean) from public, anon, authenticated;
revoke all on function public.app_guardar_variante_material(uuid,uuid,uuid,text,text,text,integer,boolean) from public, anon, authenticated;
revoke all on function public.app_solicitar_material(uuid,uuid,uuid,integer,text) from public, anon, authenticated;
revoke all on function public.app_actualizar_pedido_material(uuid,text) from public, anon, authenticated;
revoke all on function public.app_guardar_comunicacion(uuid,uuid,text,text,text,text,text,timestamptz,text,text) from public, anon, authenticated;
revoke all on function public.app_guardar_sesion(uuid,uuid,uuid,date,time,time,text,text,text,text) from public, anon, authenticated;
revoke all on function public.app_guardar_asistencia(uuid,uuid,public.estado_asistencia,text) from public, anon, authenticated;
revoke all on function public.app_registrar_checkin(uuid,uuid,text,text) from public, anon, authenticated;
revoke all on function public.app_guardar_seguimiento(uuid,uuid,text,text,public.visibilidad_seguimiento,date) from public, anon, authenticated;
revoke all on function public.app_registrar_documento(uuid,uuid,text,text,text,text,bigint,boolean) from public, anon, authenticated;
revoke all on function public.app_marcar_notificacion_leida(uuid) from public, anon, authenticated;
revoke all on function public.comunicar_pago_cuota(uuid,numeric,date,text,text,text,text) from public, anon, authenticated;
revoke all on function public.registrar_cobro_cuota(uuid,numeric,date,text,text,text) from public, anon, authenticated;
revoke all on function public.validar_pago_cuota(uuid,text,text) from public, anon, authenticated;
revoke all on function public.pausar_avisos_cuota(uuid,text,date) from public, anon, authenticated;
revoke all on function public.reactivar_avisos_cuota(uuid) from public, anon, authenticated;
revoke all on function public.app_guardar_config_avisos(uuid,smallint[],time,boolean,boolean,boolean,boolean,smallint,text,boolean) from public, anon, authenticated;
revoke all on function public.generar_cuotas_periodo(uuid,date) from public, anon, authenticated;
revoke all on function public.procesar_avisos_cobro_club(uuid,date) from public, anon, authenticated;

-- La única mutación expuesta al cliente autenticado.
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. DIAGNÓSTICO DEL CANAL REAL USADO POR WEB/APK.
-- Este diagnóstico se invoca a través de PostgREST desde la propia app.
-- ---------------------------------------------------------------------------
create or replace function public.app_write_channel_probe_v160(p_club_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare v_uid uuid:=auth.uid(); v_roles jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select coalesce(jsonb_agg(rol order by rol::text),'[]'::jsonb) into v_roles
  from public.miembros_club where club_id=p_club_id and perfil_id=v_uid and activo;
  return jsonb_build_object(
    'ok',public.es_miembro_club(p_club_id),
    'backend_version','1.6.0',
    'user_id',v_uid,
    'club_id',p_club_id,
    'roles',v_roles,
    'gateway',exists(select 1 from pg_proc where proname='app_mutate_v160'),
    'contract',exists(select 1 from pg_proc where proname='app_runtime_contract_v160')
  );
end; $$;
revoke all on function public.app_write_channel_probe_v160(uuid) from public,anon;
grant execute on function public.app_write_channel_probe_v160(uuid) to authenticated;
grant usage on schema public to authenticated;

-- ---------------------------------------------------------------------------
-- 5. SMOKE TEST TRANSACCIONAL DE LA PUERTA ÚNICA.
-- Prueba una escritura real e idempotente con un usuario Dirección existente y
-- elimina inmediatamente los datos temporales. Si falla, toda la migración revierte.
-- ---------------------------------------------------------------------------
do $$
declare
  v_club uuid;
  v_direction uuid;
  v_req uuid := gen_random_uuid();
  v_name text := 'UW-V160-SMOKE-'||substr(replace(gen_random_uuid()::text,'-',''),1,10);
  v_first jsonb;
  v_second jsonb;
  v_id uuid;
  v_old_sub text := current_setting('request.jwt.claim.sub',true);
begin
  select m.club_id,m.perfil_id into v_club,v_direction
    from public.miembros_club m
    join public.clubes c on c.id=m.club_id and c.activo
   where m.rol='direccion' and m.activo
   order by m.creado_en
   limit 1;
  if v_club is null or v_direction is null then raise exception 'V160_SMOKE_NO_ACTIVE_DIRECTION'; end if;
  perform set_config('request.jwt.claim.sub',v_direction::text,true);
  v_first := public.app_mutate_v160('disciplina.guardar',jsonb_build_object(
    'club_id',v_club,'nombre',v_name,'descripcion','Smoke test temporal','color','#ffffff','activa',true,'orden',32700
  ),v_req);
  v_second := public.app_mutate_v160('disciplina.guardar',jsonb_build_object(
    'club_id',v_club,'nombre',v_name,'descripcion','Smoke test temporal','color','#ffffff','activa',true,'orden',32700
  ),v_req);
  v_id := nullif(v_first#>>'{data,id}','')::uuid;
  if v_first->>'ok'<>'true' or v_first->>'backend_version'<>'1.6.0' or v_id is null then
    raise exception 'V160_SMOKE_GATEWAY_FAILED';
  end if;
  if v_second is distinct from v_first then raise exception 'V160_SMOKE_IDEMPOTENCY_FAILED'; end if;
  if (select count(*) from public.disciplinas where id=v_id and club_id=v_club and nombre=v_name)<>1 then
    raise exception 'V160_SMOKE_WRITE_NOT_PERSISTED';
  end if;
  delete from public.disciplinas where id=v_id;
  delete from public.app_mutation_requests where request_id=v_req;
  perform set_config('request.jwt.claim.sub',coalesce(v_old_sub,''),true);
end $$;

-- ---------------------------------------------------------------------------
-- 6. AUTOVERIFICACIÓN DE INSTALACIÓN. La propia migración falla y revierte si
-- la gobernanza queda incompleta; así un deploy nunca se apoya en media migración.
-- ---------------------------------------------------------------------------
do $$
declare v_meta public.app_runtime_meta;
begin
  select * into v_meta from public.app_runtime_meta where singleton=true;
  if v_meta.backend_version <> '1.6.0' or v_meta.schema_epoch <> 160 or v_meta.mutation_endpoint <> 'app_mutate_v160' then
    raise exception 'V160_INSTALL_META_INVALID';
  end if;
  if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null
     or to_regprocedure('public.app_runtime_contract_v160(uuid)') is null
     or to_regprocedure('public.app_write_channel_probe_v160(uuid)') is null then
    raise exception 'V160_INSTALL_FUNCTION_MISSING';
  end if;
  if not has_function_privilege('authenticated','public.app_mutate_v160(text,jsonb,uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.app_runtime_contract_v160(uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.app_write_channel_probe_v160(uuid)','EXECUTE') then
    raise exception 'V160_INSTALL_GATEWAY_NOT_EXPOSED';
  end if;
  if has_function_privilege('authenticated','public.app_guardar_disciplina(uuid,uuid,text,text,text,boolean,smallint)','EXECUTE')
     or has_function_privilege('authenticated','public.app_guardar_grupo(uuid,uuid,uuid,text,text,text,smallint,smallint,integer,boolean,jsonb)','EXECUTE')
     or has_function_privilege('authenticated','public.app_guardar_socio(uuid,uuid,text,text,date,text,text,text,uuid,uuid,uuid,text,uuid,text,text,text,text)','EXECUTE')
     or has_function_privilege('authenticated','public.app_guardar_comunicacion(uuid,uuid,text,text,text,text,text,timestamptz,text,text)','EXECUTE') then
    raise exception 'V160_INSTALL_LEGACY_RPC_STILL_EXPOSED';
  end if;
  if has_table_privilege('authenticated','public.disciplinas','INSERT')
     or has_table_privilege('authenticated','public.grupos','UPDATE')
     or has_table_privilege('authenticated','public.socios','INSERT')
     or has_table_privilege('authenticated','public.comunicaciones','DELETE') then
    raise exception 'V160_INSTALL_DIRECT_DML_STILL_EXPOSED';
  end if;
end $$;

notify pgrst, 'reload schema';
