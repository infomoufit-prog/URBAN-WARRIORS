-- KOMBAX / Urban Warriors RC13 build 20022 · archivo y papelera recuperable.
-- No incluye pagos, cuotas ni recibos. No realiza borrado físico.

begin;

alter table public.publicaciones_comunidad add column if not exists ciclo_estado text not null default 'activo',add column if not exists archivado_en timestamptz,add column if not exists archivado_por uuid references public.perfiles(id) on delete set null,add column if not exists papelera_en timestamptz,add column if not exists papelera_por uuid references public.perfiles(id) on delete set null,add column if not exists restaurar_hasta timestamptz;
alter table public.comunicaciones add column if not exists ciclo_estado text not null default 'activo',add column if not exists archivado_en timestamptz,add column if not exists archivado_por uuid references public.perfiles(id) on delete set null,add column if not exists papelera_en timestamptz,add column if not exists papelera_por uuid references public.perfiles(id) on delete set null,add column if not exists restaurar_hasta timestamptz;
alter table public.eventos_competicion add column if not exists ciclo_estado text not null default 'activo',add column if not exists archivado_en timestamptz,add column if not exists archivado_por uuid references public.perfiles(id) on delete set null,add column if not exists papelera_en timestamptz,add column if not exists papelera_por uuid references public.perfiles(id) on delete set null,add column if not exists restaurar_hasta timestamptz;
alter table public.notificaciones add column if not exists ciclo_estado text not null default 'activo',add column if not exists archivado_en timestamptz,add column if not exists archivado_por uuid references public.perfiles(id) on delete set null,add column if not exists papelera_en timestamptz,add column if not exists papelera_por uuid references public.perfiles(id) on delete set null,add column if not exists restaurar_hasta timestamptz;
alter table public.material_catalogo add column if not exists ciclo_estado text not null default 'activo',add column if not exists archivado_en timestamptz,add column if not exists archivado_por uuid references public.perfiles(id) on delete set null,add column if not exists papelera_en timestamptz,add column if not exists papelera_por uuid references public.perfiles(id) on delete set null,add column if not exists restaurar_hasta timestamptz;
alter table public.documentos_socios add column if not exists ciclo_estado text not null default 'activo',add column if not exists archivado_en timestamptz,add column if not exists archivado_por uuid references public.perfiles(id) on delete set null,add column if not exists papelera_en timestamptz,add column if not exists papelera_por uuid references public.perfiles(id) on delete set null,add column if not exists restaurar_hasta timestamptz;
alter table public.seguimiento add column if not exists ciclo_estado text not null default 'activo',add column if not exists archivado_en timestamptz,add column if not exists archivado_por uuid references public.perfiles(id) on delete set null,add column if not exists papelera_en timestamptz,add column if not exists papelera_por uuid references public.perfiles(id) on delete set null,add column if not exists restaurar_hasta timestamptz;
alter table public.asistencias add column if not exists ciclo_estado text not null default 'activo',add column if not exists archivado_en timestamptz,add column if not exists archivado_por uuid references public.perfiles(id) on delete set null,add column if not exists papelera_en timestamptz,add column if not exists papelera_por uuid references public.perfiles(id) on delete set null,add column if not exists restaurar_hasta timestamptz;
alter table public.sesiones_entrenamiento add column if not exists ciclo_estado text not null default 'activo',add column if not exists archivado_en timestamptz,add column if not exists archivado_por uuid references public.perfiles(id) on delete set null,add column if not exists papelera_en timestamptz,add column if not exists papelera_por uuid references public.perfiles(id) on delete set null,add column if not exists restaurar_hasta timestamptz;

do $$ declare t text; begin
  foreach t in array array['publicaciones_comunidad','comunicaciones','eventos_competicion','notificaciones','material_catalogo','documentos_socios','seguimiento','asistencias','sesiones_entrenamiento'] loop
    begin execute format('alter table public.%I add constraint %I check(ciclo_estado in (''activo'',''archivado'',''papelera'')) not valid',t,t||'_ciclo_estado_v038'); exception when duplicate_object then null; end;
    execute format('alter table public.%I validate constraint %I',t,t||'_ciclo_estado_v038');
    execute format('create index if not exists %I on public.%I(club_id,ciclo_estado)',t||'_ciclo_idx_v038',t);
  end loop;
end $$;

create table if not exists public.contenido_ciclo_auditoria(
  id bigint generated always as identity primary key,
  club_id uuid not null references public.clubes(id) on delete cascade,
  recurso_tipo text not null,
  recurso_id uuid not null,
  accion text not null check(accion in ('archivar','papelera','restaurar')),
  estado_anterior text not null,
  estado_nuevo text not null,
  motivo text,
  realizado_por uuid not null references public.perfiles(id) on delete restrict,
  realizado_en timestamptz not null default now(),
  check(char_length(coalesce(motivo,''))<=500)
);
create index if not exists idx_contenido_ciclo_auditoria_v038 on public.contenido_ciclo_auditoria(club_id,realizado_en desc,recurso_tipo);
alter table public.contenido_ciclo_auditoria enable row level security;
revoke all on public.contenido_ciclo_auditoria from public,anon,authenticated;
grant select on public.contenido_ciclo_auditoria to authenticated;
drop policy if exists contenido_ciclo_auditoria_select_v038 on public.contenido_ciclo_auditoria;
create policy contenido_ciclo_auditoria_select_v038 on public.contenido_ciclo_auditoria for select using(
  exists(select 1 from public.miembros_club m where m.club_id=contenido_ciclo_auditoria.club_id and m.perfil_id=auth.uid() and m.activo
    and (m.rol in ('direccion','secretaria') or coalesce(m.coordinacion,false)))
);

create or replace function public.app_puede_gestionar_ciclo_v038(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo
    and (m.rol in ('direccion','secretaria') or coalesce(m.coordinacion,false)));
$$;
revoke all on function public.app_puede_gestionar_ciclo_v038(uuid) from public,anon;
grant execute on function public.app_puede_gestionar_ciclo_v038(uuid) to authenticated;

create or replace function public.app_guard_ciclo_v038()
returns trigger language plpgsql set search_path=public as $$
begin
  if (new.ciclo_estado,new.archivado_en,new.archivado_por,new.papelera_en,new.papelera_por,new.restaurar_hasta)
     is distinct from
     (old.ciclo_estado,old.archivado_en,old.archivado_por,old.papelera_en,old.papelera_por,old.restaurar_hasta)
     and coalesce(current_setting('kombax.lifecycle_gateway',true),'')<>'on' then
    raise exception 'LIFECYCLE_GATEWAY_REQUIRED';
  end if;
  return new;
end $$;
revoke all on function public.app_guard_ciclo_v038() from public,anon,authenticated;
do $$ declare t text; begin
  foreach t in array array['publicaciones_comunidad','comunicaciones','eventos_competicion','notificaciones','material_catalogo','documentos_socios','seguimiento','asistencias','sesiones_entrenamiento'] loop
    execute format('drop trigger if exists %I on public.%I',t||'_guard_ciclo_v038',t);
    execute format('create trigger %I before update on public.%I for each row execute function public.app_guard_ciclo_v038()',t||'_guard_ciclo_v038',t);
  end loop;
end $$;

create or replace function public.app_ciclo_accion_v038(
  p_club_id uuid,p_recurso_tipo text,p_ids uuid[],p_accion text,p_motivo text default null
) returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_table text; v_id uuid; v_old text; v_new text; v_count integer:=0; v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_puede_gestionar_ciclo_v038(p_club_id) then raise exception 'LIFECYCLE_FORBIDDEN'; end if;
  if p_accion is null or p_accion not in ('archivar','papelera','restaurar') then raise exception 'LIFECYCLE_ACTION_INVALID'; end if;
  if coalesce(array_length(p_ids,1),0)=0 or array_length(p_ids,1)>200 then raise exception 'LIFECYCLE_IDS_INVALID'; end if;
  v_table:=case p_recurso_tipo
    when 'publicacion' then 'publicaciones_comunidad' when 'comunicacion' then 'comunicaciones'
    when 'evento' then 'eventos_competicion' when 'notificacion' then 'notificaciones'
    when 'material' then 'material_catalogo' when 'documento' then 'documentos_socios'
    when 'seguimiento' then 'seguimiento' when 'asistencia' then 'asistencias'
    when 'sesion' then 'sesiones_entrenamiento' else null end;
  if v_table is null then raise exception 'LIFECYCLE_RESOURCE_INVALID'; end if;
  if p_recurso_tipo='notificacion' and p_accion<>'restaurar' and exists(
    select 1 from public.notificaciones n where n.club_id=p_club_id and n.id=any(p_ids)
      and public.app_notificacion_requiere_accion_v034(n.id)
  ) then raise exception 'LIFECYCLE_ACTIONABLE_NOTIFICATION'; end if;

  perform set_config('kombax.lifecycle_gateway','on',true);
  foreach v_id in array p_ids loop
    execute format('select ciclo_estado from public.%I where club_id=$1 and id=$2 for update',v_table)
      into v_old using p_club_id,v_id;
    if v_old is null then continue; end if;
    v_new:=case p_accion when 'archivar' then 'archivado' when 'papelera' then 'papelera' else 'activo' end;
    if v_old=v_new then continue; end if;
    execute format('update public.%I set ciclo_estado=$1,archivado_en=case when $1=''archivado'' then now() when $1=''activo'' then null else archivado_en end,archivado_por=case when $1=''archivado'' then $2 when $1=''activo'' then null else archivado_por end,papelera_en=case when $1=''papelera'' then now() else null end,papelera_por=case when $1=''papelera'' then $2 else null end,restaurar_hasta=case when $1=''papelera'' then now()+interval ''30 days'' else null end where club_id=$3 and id=$4',v_table)
      using v_new,v_uid,p_club_id,v_id;
    insert into public.contenido_ciclo_auditoria(club_id,recurso_tipo,recurso_id,accion,estado_anterior,estado_nuevo,motivo,realizado_por)
    values(p_club_id,p_recurso_tipo,v_id,p_accion,v_old,v_new,nullif(btrim(coalesce(p_motivo,'')),''),v_uid);
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('ok',true,'club_id',p_club_id,'recurso_tipo',p_recurso_tipo,'accion',p_accion,'actualizados',v_count);
end $$;
revoke all on function public.app_ciclo_accion_v038(uuid,text,uuid[],text,text) from public,anon;
grant execute on function public.app_ciclo_accion_v038(uuid,text,uuid[],text,text) to authenticated;

create or replace function public.app_ciclo_listar_v038(
  p_club_id uuid,p_tipo text default null,p_estado text default null,p_desde date default null,p_hasta date default null,p_limit integer default 300
) returns table(recurso_tipo text,recurso_id uuid,ciclo_estado text,titulo text,resumen text,fecha timestamptz,restaurar_hasta timestamptz)
language sql stable security definer set search_path=public,auth as $$
  with recursos(recurso_tipo,id,club_id,ciclo_estado,titulo,resumen,fecha,restaurar_hasta) as (
    select 'publicacion'::text,id,club_id,ciclo_estado,left(coalesce(autor_nombre,'Publicación'),160),left(coalesce(texto,''),260),creado_en,restaurar_hasta from public.publicaciones_comunidad
    union all select 'comunicacion',id,club_id,ciclo_estado,left(titulo,160),left(cuerpo,260),creado_en,restaurar_hasta from public.comunicaciones
    union all select 'evento',id,club_id,ciclo_estado,left(nombre,160),left(coalesce(descripcion,''),260),coalesce(fecha::timestamptz,creado_en),restaurar_hasta from public.eventos_competicion
    union all select 'notificacion',id,club_id,ciclo_estado,left(titulo,160),left(cuerpo,260),creado_en,restaurar_hasta from public.notificaciones
    union all select 'material',id,club_id,ciclo_estado,left(nombre,160),left(coalesce(descripcion,''),260),null::timestamptz,restaurar_hasta from public.material_catalogo
    union all select 'documento',id,club_id,ciclo_estado,left(nombre,160),tipo,creado_en,restaurar_hasta from public.documentos_socios
    union all select 'seguimiento',id,club_id,ciclo_estado,left(tipo,160),left(nota,260),coalesce(fecha::timestamptz,creado_en),restaurar_hasta from public.seguimiento
    union all select 'asistencia',id,club_id,ciclo_estado,'Asistencia',left(coalesce(observacion,estado::text),260),registrado_en,restaurar_hasta from public.asistencias
    union all select 'sesion',id,club_id,ciclo_estado,'Sesión '||fecha::text,left(coalesce(monitor_nombre,estado),260),coalesce(fecha::timestamptz,creado_en),restaurar_hasta from public.sesiones_entrenamiento
  )
  select r.recurso_tipo,r.id,r.ciclo_estado,r.titulo,r.resumen,r.fecha,r.restaurar_hasta from recursos r
  where r.club_id=p_club_id and public.app_puede_gestionar_ciclo_v038(p_club_id)
    and (nullif(p_tipo,'') is null or r.recurso_tipo=p_tipo)
    and (nullif(p_estado,'') is null or r.ciclo_estado=p_estado)
    and (p_desde is null or r.fecha::date>=p_desde) and (p_hasta is null or r.fecha::date<=p_hasta)
  order by r.fecha desc nulls last,r.id desc limit least(greatest(coalesce(p_limit,300),1),500);
$$;
revoke all on function public.app_ciclo_listar_v038(uuid,text,text,date,date,integer) from public,anon;
grant execute on function public.app_ciclo_listar_v038(uuid,text,text,date,date,integer) to authenticated;

-- Reemplaza el lector optimizado para ocultar elementos archivados o en papelera.
create or replace function public.app_notificaciones_centro_v037(p_club_id uuid,p_limit integer default 500)
returns setof jsonb language sql stable security definer set search_path=public,auth as $$
  select to_jsonb(n)||jsonb_build_object(
    'leida',coalesce(l.notificacion_id is not null,n.leida,false),
    'leida_en',coalesce(l.leida_en,n.leida_en),
    'requiere_accion',public.app_notificacion_requiere_accion_v034(n.id)
  )
  from public.notificaciones n left join public.notificaciones_lecturas l on l.notificacion_id=n.id and l.perfil_id=auth.uid()
  where n.club_id=p_club_id and n.ciclo_estado='activo' and public.es_miembro_club(p_club_id)
    and (n.perfil_id=auth.uid() or n.audiencia='todos' or n.rol_destino is not null and public.tiene_rol_club(p_club_id,n.rol_destino))
  order by n.creado_en desc,n.id desc limit least(greatest(coalesce(p_limit,500),1),1000);
$$;
revoke all on function public.app_notificaciones_centro_v037(uuid,integer) from public,anon;
grant execute on function public.app_notificaciones_centro_v037(uuid,integer) to authenticated;

commit;
