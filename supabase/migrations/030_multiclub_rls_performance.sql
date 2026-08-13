-- Release J: aislamiento multiclub, cierre de DML directo e índices de escala.
begin;

-- Índices alineados con las consultas reales por club.
create index if not exists idx_socios_club_nombre on public.socios(club_id,apellidos,nombre,id);
create index if not exists idx_sesiones_club_fecha on public.sesiones_entrenamiento(club_id,fecha desc,hora_inicio desc,id);
create index if not exists idx_comunicaciones_club_feed on public.comunicaciones(club_id,estado,publicada_en desc,creado_en desc,id);
create index if not exists idx_material_catalogo_club_activo on public.material_catalogo(club_id,activo,orden,nombre,id);
create index if not exists idx_material_variantes_club_material on public.material_variantes(club_id,material_id,activa,id);
create index if not exists idx_material_entregas_club_socio_fecha on public.material_entregas(club_id,socio_id,fecha desc,id);
create index if not exists idx_dispositivos_push_club_activos on public.dispositivos_push(club_id,perfil_id,activo,ultimo_uso desc);
create index if not exists idx_notificaciones_club_feed on public.notificaciones(club_id,perfil_id,creado_en desc,id);
create index if not exists idx_notificaciones_dispatch_pendiente on public.notificaciones(club_id,creado_en,id)
  where push_enviado_en is null and push_intentos<5;
create index if not exists idx_notificaciones_lecturas_perfil on public.notificaciones_lecturas(perfil_id,leida_en desc,notificacion_id);
create index if not exists idx_mutation_requests_club_created on public.app_mutation_requests(club_id,created_at desc);

-- El dispositivo y las preferencias deben pertenecer al club activo del usuario.
drop policy if exists dispositivos_propios on public.dispositivos_push;
drop policy if exists dispositivos_propios_v030 on public.dispositivos_push;
create policy dispositivos_propios_v030 on public.dispositivos_push for all to authenticated
using(perfil_id=auth.uid() and public.es_miembro_club(club_id))
with check(perfil_id=auth.uid() and public.es_miembro_club(club_id));

drop policy if exists preferencias_notificacion_propias on public.preferencias_notificacion;
drop policy if exists preferencias_notificacion_propias_v030 on public.preferencias_notificacion;
create policy preferencias_notificacion_propias_v030 on public.preferencias_notificacion for select to authenticated
using(perfil_id=auth.uid() and public.es_miembro_club(club_id));

-- Una lectura solo puede referirse a una notificación visible para ese perfil.
drop policy if exists notificaciones_lecturas_insertar on public.notificaciones_lecturas;
drop policy if exists notificaciones_lecturas_insertar_v030 on public.notificaciones_lecturas;
create policy notificaciones_lecturas_insertar_v030 on public.notificaciones_lecturas for insert to authenticated
with check(
  perfil_id=auth.uid() and exists(
    select 1 from public.notificaciones n where n.id=notificacion_id and (
      n.perfil_id=auth.uid()
      or (n.rol_destino is not null and public.tiene_rol_club(n.club_id,n.rol_destino))
      or (n.audiencia='todos' and public.es_miembro_club(n.club_id))
    )
  )
);

-- Guardar privilegios efectivos antes de cerrar las escrituras directas.
create table if not exists public.app_privilege_snapshot_v030(
  role_name text not null,
  table_name text not null,
  privilege text not null,
  had_privilege boolean not null,
  primary key(role_name,table_name,privilege)
);
revoke all on public.app_privilege_snapshot_v030 from public,anon,authenticated;

do $snapshot$
declare
  v_role text;
  v_table text;
  v_priv text;
begin
  foreach v_role in array array['anon','authenticated'] loop
    foreach v_table in array array[
      'perfiles','miembros_club','config_club','disciplinas','grados','grupos','socios',
      'sesiones_entrenamiento','comunicaciones','publicaciones_comunidad','cuotas','pagos','recibos_cuota',
      'material_catalogo','material_variantes','material_pedidos','material_entregas',
      'dispositivos_push','preferencias_notificacion','notificaciones','notificaciones_lecturas',
      'configuracion_avisos_cuota'
    ] loop
      if to_regclass('public.'||v_table) is not null then
        foreach v_priv in array array['INSERT','UPDATE','DELETE'] loop
          insert into public.app_privilege_snapshot_v030(role_name,table_name,privilege,had_privilege)
          values(v_role,v_table,v_priv,has_table_privilege(v_role,format('public.%I',v_table),v_priv))
          on conflict(role_name,table_name,privilege) do nothing;
        end loop;
        execute format('revoke insert,update,delete on table public.%I from %I',v_table,v_role);
      end if;
    end loop;
  end loop;
end
$snapshot$;

-- Diagnóstico auditable de recursos multiclub (metadatos, no datos de negocio).
create or replace function public.app_multiclub_audit_v030()
returns table(resource text,has_club_id boolean,rls_enabled boolean,tenant_index boolean,direct_client_dml boolean)
language sql stable security definer set search_path=public,pg_catalog
as $$
  select c.relname::text,
    exists(select 1 from information_schema.columns x where x.table_schema='public' and x.table_name=c.relname and x.column_name='club_id'),
    c.relrowsecurity,
    exists(select 1 from pg_index i where i.indrelid=c.oid and strpos(pg_get_indexdef(i.indexrelid),'(club_id')>0),
    has_table_privilege('authenticated',c.oid,'INSERT') or has_table_privilege('authenticated',c.oid,'UPDATE') or has_table_privilege('authenticated',c.oid,'DELETE')
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind in ('r','p') and c.relname=any(array[
    'miembros_club','config_club','disciplinas','grados','grupos','socios','sesiones_entrenamiento','comunicaciones',
    'publicaciones_comunidad','cuotas','pagos','material_catalogo','material_variantes',
    'material_pedidos','material_entregas','dispositivos_push','preferencias_notificacion'
  ])
  order by c.relname;
$$;
revoke all on function public.app_multiclub_audit_v030() from public,anon;
grant execute on function public.app_multiclub_audit_v030() to authenticated;

notify pgrst,'reload schema';
commit;

select * from public.app_multiclub_audit_v030();
