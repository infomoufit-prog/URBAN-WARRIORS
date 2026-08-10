-- ============================================================================
-- URBAN WARRIORS 2.0 RC9 · GESTOR DE LA APP + COORDINACIÓN · v165
-- Ejecutar DESPUÉS de 020_session_reservations_document_download_v164.sql.
-- Idempotente. Mantiene backend 1.6.0 / epoch 160 / app_mutate_v160.
--
-- Diseño de compatibilidad:
-- - El rol interno histórico `direccion` NO se renombra en PostgreSQL: en UI pasa
--   a llamarse "Gestor de la app" y conserva el máximo nivel.
-- - "Coordinación" es un nivel operativo compuesto y explícito. Se materializa
--   mediante las membresías existentes secretaria + economia + comunicacion,
--   marcadas con coordinacion=true. Así reutiliza RLS ya certificado sin otorgar
--   privilegios exclusivos de `direccion` (invitaciones, borrado total, E2E).
-- ============================================================================
begin;

-- 1) Marca explícita de coordinación, sin modificar el enum rol_club.
alter table public.miembros_club
  add column if not exists coordinacion boolean not null default false;
alter table public.invitaciones_club
  add column if not exists coordinacion boolean not null default false;
create index if not exists miembros_club_coordinacion_idx
  on public.miembros_club(club_id,perfil_id) where coordinacion and activo;

-- 2) Encapsular RC8 y conservar una sola puerta pública de mutación.
do $$
begin
  if to_regprocedure('public.app_mutate_v160_v164(text,jsonb,uuid)') is null
     and to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_v164;
  end if;
end $$;
revoke all on function public.app_mutate_v160_v164(text,jsonb,uuid) from public,anon,authenticated;

-- 3) Wrapper RC9. Intercepta únicamente invitaciones/aceptación de Coordinación.
--    Las 62 operaciones anteriores siguen delegándose a RC8 v164.
create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid := auth.uid();
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
  v_club_id uuid;
  v_legacy jsonb;
  v_result jsonb;
  v_inv_id uuid;
  v_token uuid;
  v_coord boolean := false;
  v_inv public.invitaciones_club;
begin
  -- Crear invitación de Coordinación sin introducir un nuevo valor en rol_club.
  if p_operation='invitacion.crear' and lower(trim(coalesce(v_payload->>'rol','')))='coordinacion' then
    if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
    begin v_club_id := nullif(trim(coalesce(v_payload->>'club_id','')),'')::uuid;
    exception when invalid_text_representation then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
    if v_club_id is null or not public.tiene_rol_club(v_club_id,'direccion') then
      raise exception 'Solo el Gestor de la app puede invitar a Coordinación';
    end if;

    v_legacy := public.app_mutate_v160_v164(
      'invitacion.crear',
      jsonb_set(v_payload,'{rol}',to_jsonb('secretaria'::text),true),
      p_request_id
    );
    v_inv_id := nullif(v_legacy->'data'->>'id','')::uuid;
    if v_inv_id is null then raise exception 'No se pudo identificar la invitación creada'; end if;
    update public.invitaciones_club set coordinacion=true where id=v_inv_id and club_id=v_club_id;

    v_result := jsonb_set(v_legacy,'{data,rol}',to_jsonb('coordinacion'::text),true);
    update public.app_mutation_requests set result=v_result where request_id=p_request_id;
    return v_result;
  end if;

  -- Al aceptar una invitación marcada, RC8 activa Secretaría y RC9 añade los
  -- permisos operativos complementarios. Nunca añade `direccion`.
  if p_operation='invitacion.aceptar' then
    begin v_token := nullif(trim(coalesce(v_payload->>'token','')),'')::uuid;
    exception when invalid_text_representation then raise exception 'Invitación no válida'; end;
    if v_token is not null then
      select * into v_inv from public.invitaciones_club where token=v_token limit 1;
      v_coord := coalesce(v_inv.coordinacion,false);
    end if;

    v_legacy := public.app_mutate_v160_v164(p_operation,p_payload,p_request_id);
    if v_coord then
      v_club_id := coalesce(v_inv.club_id,nullif(v_legacy->'data'->>'club_id','')::uuid);
      if v_club_id is null then raise exception 'No se pudo resolver el club de Coordinación'; end if;

      insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
      values
        (v_club_id,v_uid,'secretaria',true,true),
        (v_club_id,v_uid,'economia',true,true),
        (v_club_id,v_uid,'comunicacion',true,true)
      on conflict(club_id,perfil_id,rol) do update
        set activo=true,coordinacion=true;

      -- Evitar que queden otras filas auxiliares marcadas por accidente.
      update public.miembros_club
         set coordinacion=false
       where club_id=v_club_id and perfil_id=v_uid
         and rol not in ('secretaria','economia','comunicacion');

      v_result := jsonb_set(v_legacy,'{data,rol}',to_jsonb('coordinacion'::text),true);
      update public.app_mutation_requests set result=v_result where request_id=p_request_id;
      return v_result;
    end if;
    return v_legacy;
  end if;

  return public.app_mutate_v160_v164(p_operation,p_payload,p_request_id);
end; $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- 4) Diagnóstico RC9: reservado al Gestor de la app.
create or replace function public.app_diagnostico_final_v165()
returns table(control text,estado text,detalle text)
language plpgsql security definer set search_path=public,auth
as $$
declare v_club uuid;
begin
  select club_id into v_club
  from public.miembros_club
  where perfil_id=auth.uid() and activo and rol='direccion'
  order by creado_en limit 1;
  if v_club is null then raise exception 'Solo el Gestor de la app puede ejecutar el diagnóstico técnico'; end if;

  return query
    select 'marca coordinación',case when exists(
      select 1 from information_schema.columns where table_schema='public' and table_name='miembros_club' and column_name='coordinacion'
    ) then 'OK' else 'FALLO' end,'nivel operativo explícito sin cambiar rol_club' union all
    select 'invitación coordinación',case when exists(
      select 1 from information_schema.columns where table_schema='public' and table_name='invitaciones_club' and column_name='coordinacion'
    ) then 'OK' else 'FALLO' end,'invitación única que activa permisos compuestos' union all
    select 'gateway RC9',case when to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then 'OK' else 'FALLO' end,'puerta única activa' union all
    select 'RC8 encapsulado',case when to_regprocedure('public.app_mutate_v160_v164(text,jsonb,uuid)') is not null then 'OK' else 'FALLO' end,'62 operaciones anteriores preservadas' union all
    select 'gestor activo',case when public.tiene_rol_club(v_club,'direccion') then 'OK' else 'FALLO' end,'direccion interno = Gestor de la app en la interfaz' union all
    select 'coordinación sin dirección',case when not exists(
      select 1 from public.miembros_club m
      where m.club_id=v_club and m.coordinacion and m.activo and m.rol='direccion'
    ) then 'OK' else 'FALLO' end,'Coordinación nunca recibe el rol interno de máximo nivel';
end; $$;
revoke all on function public.app_diagnostico_final_v165() from public,anon;
grant execute on function public.app_diagnostico_final_v165() to authenticated;

commit;

select * from public.app_diagnostico_final_v165();
