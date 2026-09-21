-- Rollback exacto de privilegios/políticas; no elimina datos ni columnas.
begin;

do $restore$
declare v record;
begin
  if to_regclass('public.app_privilege_snapshot_v030') is null then raise exception 'Rollback 030 no disponible'; end if;
  for v in select * from public.app_privilege_snapshot_v030 where had_privilege loop
    execute format('grant %s on table public.%I to %I',v.privilege,v.table_name,v.role_name);
  end loop;
end
$restore$;

drop policy if exists dispositivos_propios_v030 on public.dispositivos_push;
create policy dispositivos_propios on public.dispositivos_push for all
using(perfil_id=auth.uid()) with check(perfil_id=auth.uid());

drop policy if exists preferencias_notificacion_propias_v030 on public.preferencias_notificacion;
create policy preferencias_notificacion_propias on public.preferencias_notificacion for select to authenticated
using(perfil_id=auth.uid());

drop policy if exists notificaciones_lecturas_insertar_v030 on public.notificaciones_lecturas;
create policy notificaciones_lecturas_insertar on public.notificaciones_lecturas for insert to authenticated
with check(perfil_id=auth.uid());

drop function if exists public.app_multiclub_audit_v030();
drop index if exists public.idx_socios_club_nombre;
drop index if exists public.idx_sesiones_club_fecha;
drop index if exists public.idx_comunicaciones_club_feed;
drop index if exists public.idx_material_catalogo_club_activo;
drop index if exists public.idx_material_variantes_club_material;
drop index if exists public.idx_material_entregas_club_socio_fecha;
drop index if exists public.idx_dispositivos_push_club_activos;
drop index if exists public.idx_notificaciones_club_feed;
drop index if exists public.idx_notificaciones_dispatch_pendiente;
drop index if exists public.idx_notificaciones_lecturas_perfil;
drop index if exists public.idx_mutation_requests_club_created;
drop table public.app_privilege_snapshot_v030;

notify pgrst,'reload schema';
commit;
