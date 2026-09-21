-- VERIFICACIÓN 030 DE SOLO LECTURA. Resultado requerido: 8/8 OK.
select control,estado,detalle from (
  select 1 orden,'auditor 030'::text control,
    case when to_regprocedure('public.app_multiclub_audit_v030()') is not null
      then 'OK' else 'FALLO' end estado,
    'función disponible'::text detalle
  union all
  select 2,'snapshot de rollback',
    case when to_regclass('public.app_privilege_snapshot_v030') is not null
      then 'OK' else 'FALLO' end,
    'privilegios anteriores preservados'
  union all
  select 3,'índices 030',
    case when count(*)=11 then 'OK' else 'FALLO' end,
    count(*)::text||'/11'
  from pg_indexes where schemaname='public' and indexname=any(array[
    'idx_socios_club_nombre','idx_sesiones_club_fecha','idx_comunicaciones_club_feed',
    'idx_material_catalogo_club_activo','idx_material_variantes_club_material',
    'idx_material_entregas_club_socio_fecha',
    'idx_dispositivos_push_club_activos','idx_notificaciones_club_feed',
    'idx_notificaciones_dispatch_pendiente','idx_notificaciones_lecturas_perfil',
    'idx_mutation_requests_club_created'
  ])
  union all
  select 4,'políticas 030',
    case when count(*)=3 then 'OK' else 'FALLO' end,
    count(*)::text||'/3'
  from pg_policies where schemaname='public' and policyname in (
    'dispositivos_propios_v030','preferencias_notificacion_propias_v030',
    'notificaciones_lecturas_insertar_v030'
  )
  union all
  select 5,'aislamiento club_id',
    case when bool_and(has_club_id) then 'OK' else 'FALLO' end,
    count(*)::text||' recursos auditados'
  from public.app_multiclub_audit_v030()
  union all
  select 6,'RLS multiclub',
    case when bool_and(rls_enabled) then 'OK' else 'FALLO' end,
    count(*)::text||' recursos auditados'
  from public.app_multiclub_audit_v030()
  union all
  select 7,'índices por tenant',
    case when bool_and(tenant_index) then 'OK' else 'FALLO' end,
    count(*) filter(where not tenant_index)::text||' recursos sin índice club_id'
  from public.app_multiclub_audit_v030()
  union all
  select 8,'DML directo cerrado',
    case when not bool_or(direct_client_dml) then 'OK' else 'FALLO' end,
    count(*) filter(where direct_client_dml)::text||' recursos con escritura directa'
  from public.app_multiclub_audit_v030()
) checks order by orden;

-- Debajo debe aparecer una fila por recurso; todo debe ser true/true/true/false.
select * from public.app_multiclub_audit_v030();
