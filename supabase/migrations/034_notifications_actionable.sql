-- Urban Warriors RC13 build 20018 · 034
-- Centro de notificaciones: las acciones pendientes no se pueden ocultar mediante lectura masiva.
-- Requiere 033 y conserva el gateway/contrato 1.6.0 / epoch 160.

begin;

create table if not exists public.notificaciones_revisiones (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  notificacion_id uuid not null references public.notificaciones(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  ruta text,
  revisada_en timestamptz not null default now(),
  unique(notificacion_id,perfil_id)
);
create index if not exists idx_notificaciones_revisiones_club_perfil_v034
  on public.notificaciones_revisiones(club_id,perfil_id,revisada_en desc);
alter table public.notificaciones_revisiones enable row level security;
drop policy if exists notificaciones_revisiones_propias_v034 on public.notificaciones_revisiones;
create policy notificaciones_revisiones_propias_v034 on public.notificaciones_revisiones
for select to authenticated using(perfil_id=auth.uid() and public.es_miembro_club(club_id));
revoke all on public.notificaciones_revisiones from public,anon,authenticated;
grant select on public.notificaciones_revisiones to authenticated;

-- Determina si la notificación visible para el usuario todavía exige una acción real.
-- La decisión usa el estado vivo del objeto relacionado; no basta con el tipo del aviso.
create or replace function public.app_notificacion_requiere_accion_v034(p_notificacion_id uuid)
returns boolean
language plpgsql stable security definer set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_n public.notificaciones;
  v_id uuid;
  v_flag text;
begin
  if v_uid is null then return false; end if;
  select * into v_n
  from public.notificaciones n
  where n.id=p_notificacion_id
    and (
      n.perfil_id=v_uid
      or n.audiencia='todos' and public.es_miembro_club(n.club_id)
      or n.rol_destino is not null and public.tiene_rol_club(n.club_id,n.rol_destino)
    );
  if v_n.id is null then return false; end if;

  v_flag:=lower(coalesce(v_n.datos->>'requiere_accion',''));
  if v_flag in ('true','1','si','sí') then return true; end if;
  if v_flag in ('false','0','no') then return false; end if;

  if v_n.tipo='inscripcion' and nullif(v_n.datos->>'preinscripcion_id','') is not null then
    begin v_id:=(v_n.datos->>'preinscripcion_id')::uuid; exception when others then return false; end;
    return exists(
      select 1 from public.preinscripciones p
      where p.club_id=v_n.club_id and p.id=v_id
        and p.estado in ('enviada','en_revision','pendiente_documentacion')
        and public.tiene_rol_club(v_n.club_id,'direccion','secretaria')
    );
  end if;

  if v_n.tipo='material' and nullif(v_n.datos->>'pedido_id','') is not null then
    begin v_id:=(v_n.datos->>'pedido_id')::uuid; exception when others then return false; end;
    return exists(
      select 1 from public.material_pedidos mp
      where mp.club_id=v_n.club_id and mp.id=v_id
        and mp.estado in ('reservado','pendiente_validacion','preparado')
        and public.tiene_rol_club(v_n.club_id,'direccion','secretaria','economia')
    );
  end if;

  if v_n.tipo in ('cuota','pago','validacion_pago') and nullif(v_n.datos->>'pago_id','') is not null then
    begin v_id:=(v_n.datos->>'pago_id')::uuid; exception when others then return false; end;
    return exists(
      select 1 from public.pagos p
      where p.club_id=v_n.club_id and p.id=v_id and p.estado_validacion='pendiente'
        and public.tiene_rol_club(v_n.club_id,'direccion','secretaria','economia')
    );
  end if;

  if v_n.tipo in ('cuota','aviso_cobro') and nullif(v_n.datos->>'cuota_id','') is not null then
    begin v_id:=(v_n.datos->>'cuota_id')::uuid; exception when others then return false; end;
    return exists(
      select 1 from public.cuotas q
      where q.club_id=v_n.club_id and q.id=v_id
        and q.estado in ('pendiente','vencida','parcialmente_pagada','pendiente_validacion')
        and (
          public.puede_aportar_pago_socio(q.socio_id)
          or public.tiene_rol_club(v_n.club_id,'direccion','secretaria','economia')
        )
    );
  end if;

  if v_n.tipo='cuota' and nullif(v_n.datos->>'cantidad','') is not null
     and public.tiene_rol_club(v_n.club_id,'direccion','secretaria','economia') then
    return exists(select 1 from public.cuotas q where q.club_id=v_n.club_id and q.estado='vencida');
  end if;

  return false;
end
$$;
revoke all on function public.app_notificacion_requiere_accion_v034(uuid) from public,anon;
grant execute on function public.app_notificacion_requiere_accion_v034(uuid) to authenticated;

create or replace function public.app_notificaciones_accionables_v034(p_club_id uuid)
returns table(notificacion_id uuid,requiere_accion boolean)
language sql stable security definer set search_path=public,auth
as $$
  select n.id,public.app_notificacion_requiere_accion_v034(n.id)
  from public.notificaciones n
  where n.club_id=p_club_id
    and public.es_miembro_club(p_club_id)
    and (
      n.perfil_id=auth.uid()
      or n.audiencia='todos'
      or n.rol_destino is not null and public.tiene_rol_club(p_club_id,n.rol_destino)
    )
  order by n.creado_en desc,n.id;
$$;
revoke all on function public.app_notificaciones_accionables_v034(uuid) from public,anon;
grant execute on function public.app_notificaciones_accionables_v034(uuid) to authenticated;

-- Extiende el contrato con la única operación realmente nueva: revisar una acción.
do $contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_notifications_034(uuid)') is null then
    if to_regprocedure('public.app_runtime_contract_v160(uuid)') is null then raise exception '034: falta app_runtime_contract_v160'; end if;
    alter function public.app_runtime_contract_v160(uuid) rename to app_runtime_contract_v160_pre_notifications_034;
  end if;
end
$contract$;
revoke all on function public.app_runtime_contract_v160_pre_notifications_034(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare v_base jsonb;
begin
  v_base:=public.app_runtime_contract_v160_pre_notifications_034(p_club_id);
  return jsonb_set(v_base,'{operations}',coalesce(v_base->'operations','[]'::jsonb)||jsonb_build_array('notificacion.revisar'),true);
end
$$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

-- Gateway: endurece también las operaciones antiguas para que clientes anteriores
-- no puedan marcar de forma masiva una tarea que continúa pendiente.
do $migration$
begin
  if to_regprocedure('public.app_mutate_v160_pre_notifications_034(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then raise exception '034: falta app_mutate_v160'; end if;
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_notifications_034;
  end if;
end
$migration$;
revoke all on function public.app_mutate_v160_pre_notifications_034(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_club uuid;
  v_existing public.app_mutation_requests;
  v_result jsonb;
  v_id uuid;
  v_tipo text;
  v_count integer:=0;
begin
  if p_operation not in ('notificacion.leer','notificacion.leer_grupo','notificacion.leer_todas','notificacion.revisar') then
    return public.app_mutate_v160_pre_notifications_034(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation);
  end if;

  if p_operation='notificacion.leer' then
    begin v_id:=(v_payload->>'notificacion_id')::uuid; exception when others then raise exception 'NOTIFICACION_ID_INVALIDA'; end;
    if public.app_notificacion_requiere_accion_v034(v_id) then
      raise exception 'Esta notificación requiere revisión antes de marcarla como leída';
    end if;
    perform public.app_marcar_notificacion_leida(v_id);
    v_result:=jsonb_build_object('notificacion_id',v_id,'leida',true,'requiere_accion',false);

  elsif p_operation='notificacion.revisar' then
    begin v_id:=(v_payload->>'notificacion_id')::uuid; exception when others then raise exception 'NOTIFICACION_ID_INVALIDA'; end;
    if not exists(
      select 1 from public.notificaciones n where n.id=v_id and n.club_id=v_club and (
        n.perfil_id=v_uid or n.audiencia='todos' or n.rol_destino is not null and public.tiene_rol_club(v_club,n.rol_destino)
      )
    ) then raise exception 'Notificación no disponible'; end if;
    perform public.app_marcar_notificacion_leida(v_id);
    insert into public.notificaciones_revisiones(club_id,notificacion_id,perfil_id,ruta,revisada_en)
    select v_club,n.id,v_uid,n.ruta,now() from public.notificaciones n where n.id=v_id
    on conflict(notificacion_id,perfil_id) do update set ruta=excluded.ruta,revisada_en=now();
    v_result:=jsonb_build_object('notificacion_id',v_id,'revisada',true);

  elsif p_operation='notificacion.leer_todas' then
    insert into public.notificaciones_lecturas(notificacion_id,perfil_id)
    select n.id,v_uid
    from public.notificaciones n
    where n.club_id=v_club
      and (n.perfil_id=v_uid or n.audiencia='todos' or n.rol_destino is not null and public.tiene_rol_club(v_club,n.rol_destino))
      and not public.app_notificacion_requiere_accion_v034(n.id)
    on conflict(notificacion_id,perfil_id) do update set leida_en=now();
    get diagnostics v_count=row_count;
    update public.notificaciones n set leida=true,leida_en=now()
    where n.club_id=v_club and n.perfil_id=v_uid and not public.app_notificacion_requiere_accion_v034(n.id);
    v_result:=jsonb_build_object('marcadas_informativas',v_count,'accionables_conservadas',(
      select count(*) from public.notificaciones n where n.club_id=v_club
        and (n.perfil_id=v_uid or n.audiencia='todos' or n.rol_destino is not null and public.tiene_rol_club(v_club,n.rol_destino))
        and public.app_notificacion_requiere_accion_v034(n.id)
    ));

  else
    v_tipo:=coalesce(nullif(v_payload->>'tipo',''),'general');
    insert into public.notificaciones_lecturas(notificacion_id,perfil_id)
    select n.id,v_uid
    from public.notificaciones n
    where n.club_id=v_club and coalesce(n.tipo,'general')=v_tipo
      and (n.perfil_id=v_uid or n.audiencia='todos' or n.rol_destino is not null and public.tiene_rol_club(v_club,n.rol_destino))
      and not public.app_notificacion_requiere_accion_v034(n.id)
    on conflict(notificacion_id,perfil_id) do update set leida_en=now();
    get diagnostics v_count=row_count;
    update public.notificaciones n set leida=true,leida_en=now()
    where n.club_id=v_club and n.perfil_id=v_uid and coalesce(n.tipo,'general')=v_tipo
      and not public.app_notificacion_requiere_accion_v034(n.id);
    v_result:=jsonb_build_object('tipo',v_tipo,'marcadas_informativas',v_count);
  end if;

  v_result:=jsonb_build_object('ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end
$$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

do $audit$
begin
  if to_regprocedure('public.app_mutate_v160_pre_notifications_034(text,jsonb,uuid)') is null then raise exception '034: gateway anterior no preservado'; end if;
  if to_regprocedure('public.app_runtime_contract_v160_pre_notifications_034(uuid)') is null then raise exception '034: contrato anterior no preservado'; end if;
  if to_regprocedure('public.app_notificaciones_accionables_v034(uuid)') is null then raise exception '034: falta lectura de accionabilidad'; end if;
  if not exists(select 1 from pg_class where oid='public.notificaciones_revisiones'::regclass and relrowsecurity) then raise exception '034: RLS no activa en revisiones'; end if;
end
$audit$;

notify pgrst,'reload schema';
commit;
