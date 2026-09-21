-- ============================================================================
-- URBAN WARRIORS 1.6.1 — RECUPERACIÓN DE PERSISTENCIA
-- Ejecutar DESPUÉS de 016_recibos_cuota.sql. Es idempotente: puede ejecutarse
-- tantas veces como haga falta sin efectos secundarios.
--
-- Por qué existe (causa raíz demostrada):
--   La migración 015 abortaba con V160_SMOKE_NO_ACTIVE_DIRECTION cuando el club
--   todavía no tenía ninguna cuenta con rol 'direccion'. Como el SQL Editor
--   ejecuta el archivo en una única transacción, la excepción revertía la
--   migración ENTERA: no quedaban ni app_mutate_v160 ni
--   app_runtime_contract_v160. La app arrancaba, el usuario iniciaba sesión y
--   ninguna escritura se completaba nunca.
--
-- Esta migración NO cambia la arquitectura ni el contrato 1.6.0. Solo:
--   1. Permite crear la primera cuenta de dirección sin editar tablas a mano.
--   2. Vuelve a sellar los permisos heredados (idempotente).
--   3. Diagnostica el estado real sin abortar nada.
--   4. Refresca la caché de esquema de PostgREST.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. BOOTSTRAP DE LA PRIMERA CUENTA DE DIRECCIÓN
-- Resuelve la dependencia circular: 015 necesitaba una dirección activa, pero
-- la única vía documentada para crearla pasaba por la propia app, que no podía
-- escribir sin 015. Se ejecuta desde el SQL Editor, nunca desde el navegador.
-- ---------------------------------------------------------------------------
create or replace function public.app_bootstrap_direccion(
  p_email text,
  p_club_slug text default 'urban-warriors'
) returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_user uuid;
  v_club uuid;
  v_nombre text;
begin
  select id, coalesce(raw_user_meta_data->>'nombre', split_part(email,'@',1))
    into v_user, v_nombre
    from auth.users where lower(email)=lower(trim(p_email)) limit 1;
  if v_user is null then
    raise exception 'BOOTSTRAP_USUARIO_NO_EXISTE: crea primero la cuenta % en Authentication → Users', p_email;
  end if;

  select id into v_club from public.clubes where slug=p_club_slug and activo limit 1;
  if v_club is null then
    raise exception 'BOOTSTRAP_CLUB_NO_EXISTE: ejecuta antes supabase/setup/bootstrap_urban_warriors_club.sql';
  end if;

  insert into public.perfiles(id,nombre,apellidos)
  values(v_user, coalesce(nullif(v_nombre,''),'Dirección'), '')
  on conflict (id) do nothing;

  insert into public.miembros_club(club_id,perfil_id,rol,activo)
  values(v_club,v_user,'direccion',true)
  on conflict (club_id,perfil_id,rol) do update set activo=true;

  return jsonb_build_object(
    'ok',true,'email',p_email,'perfil_id',v_user,'club_id',v_club,'rol','direccion'
  );
end; $$;
revoke all on function public.app_bootstrap_direccion(text,text) from public, anon, authenticated;
grant execute on function public.app_bootstrap_direccion(text,text) to postgres, service_role;

-- ---------------------------------------------------------------------------
-- 2. RESELLADO IDEMPOTENTE DE LA GOBERNANZA
-- Las migraciones 007, 008 y 012 terminan con `grant execute ... to
-- authenticated` sobre las RPC heredadas. Volver a ejecutarlas después de 015
-- reabría la ruta de escritura no gobernada sin ningún aviso. Este bloque se
-- puede lanzar siempre que se sospeche de una regresión de permisos.
-- ---------------------------------------------------------------------------
do $$
declare
  v_sig text;
  v_reselladas integer := 0;
begin
  for v_sig in
    select p.oid::regprocedure::text
      from pg_proc p
      join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='public'
       and (p.proname like 'app\_guardar\_%' escape '\'
         or p.proname like 'app\_crear\_%'   escape '\'
         or p.proname in (
              'app_aprobar_preinscripcion','app_lista_espera_preinscripcion','app_rechazar_preinscripcion',
              'app_solicitar_nueva_matricula','app_desactivar_matricula','app_registrar_graduacion',
              'app_solicitar_material','app_actualizar_pedido_material','app_registrar_checkin',
              'app_registrar_documento','app_marcar_notificacion_leida','comunicar_pago_cuota',
              'registrar_cobro_cuota','validar_pago_cuota','pausar_avisos_cuota','reactivar_avisos_cuota',
              'generar_cuotas_periodo','procesar_avisos_cobro_club','registrar_cuenta_club',
              'aceptar_invitacion_club','crear_invitacion_club'))
  loop
    execute format('revoke all on function %s from public, anon, authenticated', v_sig);
    v_reselladas := v_reselladas + 1;
  end loop;
  raise notice 'V161: % RPC heredadas resellada(s) fuera del alcance de anon/authenticated.', v_reselladas;
end $$;

-- La puerta única y sus dos funciones de lectura siguen siendo lo único expuesto.
do $$
begin
  if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then
    grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;
    grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;
    grant execute on function public.app_write_channel_probe_v160(uuid) to authenticated;
  end if;
end $$;

-- Contrato de runtime siempre coherente con el frontend 1.6.0.
-- Se protege con to_regclass para que 017 pueda ejecutarse en cualquier orden y
-- en cualquier estado, incluso si 015 todavía no se ha aplicado.
do $$
begin
  if to_regclass('public.app_runtime_meta') is not null then
    insert into public.app_runtime_meta(singleton,backend_version,schema_epoch,mutation_endpoint,updated_at)
    values(true,'1.6.0',160,'app_mutate_v160',now())
    on conflict(singleton) do update set
      backend_version=excluded.backend_version,
      schema_epoch=excluded.schema_epoch,
      mutation_endpoint=excluded.mutation_endpoint,
      updated_at=excluded.updated_at;
  else
    raise notice 'V161: app_runtime_meta no existe todavía; ejecuta 015 después de crear la cuenta de dirección.';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. DIAGNÓSTICO NO DESTRUCTIVO
-- Devuelve el estado real de la cadena de persistencia. No aborta nunca: su
-- trabajo es informar, no romper el despliegue.
-- ---------------------------------------------------------------------------
create or replace function public.app_diagnostico_persistencia_v161()
returns table(control text, estado text, detalle text)
language plpgsql security definer set search_path=public,auth
as $$
begin
  return query
  select 'puerta app_mutate_v160'::text,
         case when to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then 'OK' else 'FALLO' end,
         'sin ella ninguna escritura es posible'::text
  union all
  select 'contrato app_runtime_contract_v160',
         case when to_regprocedure('public.app_runtime_contract_v160(uuid)') is not null then 'OK' else 'FALLO' end,
         'se comprueba en cada inicio de sesión'
  union all
  select 'contrato = 1.6.0 / 160 / app_mutate_v160',
         case when exists(select 1 from public.app_runtime_meta
                          where singleton and backend_version='1.6.0' and schema_epoch=160
                            and mutation_endpoint='app_mutate_v160') then 'OK' else 'FALLO' end,
         'debe coincidir con web/config.js'
  union all
  select 'authenticated puede ejecutar la puerta',
         case when to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null
               and has_function_privilege('authenticated','public.app_mutate_v160(text,jsonb,uuid)','EXECUTE')
              then 'OK' else 'FALLO' end,
         'sin GRANT, PostgREST responde 404'
  union all
  select 'RPC heredadas cerradas',
         case when to_regprocedure('public.app_guardar_disciplina(uuid,uuid,text,text,text,boolean,smallint)') is not null
               and has_function_privilege('authenticated','public.app_guardar_disciplina(uuid,uuid,text,text,text,boolean,smallint)','EXECUTE')
              then 'AVISO' else 'OK' end,
         'AVISO = se reejecutó 007/008/012 tras 015'
  union all
  select 'DML directo cerrado',
         case when has_table_privilege('authenticated','public.disciplinas','INSERT')
                or has_table_privilege('authenticated','public.grupos','UPDATE')
              then 'AVISO' else 'OK' end,
         'AVISO = gobernanza revertida parcialmente'
  union all
  select 'recibos_cuota (016)',
         case when to_regclass('public.recibos_cuota') is not null then 'OK' else 'FALLO' end,
         'su ausencia vacía pantallas sin avisar'
  union all
  select 'cuenta con rol direccion activa',
         case when exists(select 1 from public.miembros_club where rol='direccion' and activo) then 'OK' else 'FALLO' end,
         'ejecuta app_bootstrap_direccion(''correo'')'
  union all
  select 'disciplina activa disponible',
         case when exists(select 1 from public.disciplinas where activa) then 'OK' else 'AVISO' end,
         'app_guardar_grupo exige una disciplina activa';
end; $$;
revoke all on function public.app_diagnostico_persistencia_v161() from public, anon;
grant execute on function public.app_diagnostico_persistencia_v161() to postgres, service_role, authenticated;

-- ---------------------------------------------------------------------------
-- 4. VERIFICACIÓN ESTRUCTURAL (sí aborta: aquí no hay dependencia de datos)
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.app_bootstrap_direccion(text,text)') is null
     or to_regprocedure('public.app_diagnostico_persistencia_v161()') is null then
    raise exception 'V161_INSTALL_INCOMPLETA';
  end if;
end $$;

notify pgrst, 'reload schema';
