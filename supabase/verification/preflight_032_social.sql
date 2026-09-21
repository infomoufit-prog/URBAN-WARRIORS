-- Urban Warriors RC13 · preflight 032. SOLO LECTURA.
-- Requiere haber certificado antes 031 para no mezclar cambios sociales con un backend financiero pendiente.
select * from (values
  ('gateway_actual',to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null),
  ('finance_031_certificable',to_regprocedure('public.app_finance_receipts_audit_v031()') is not null),
  ('hardening_030',to_regprocedure('public.app_multiclub_audit_v030()') is not null),
  ('comunidad_base',to_regclass('public.publicaciones_comunidad') is not null),
  ('socios_base',to_regclass('public.socios') is not null and to_regclass('public.tutores_socios') is not null),
  ('storage_disponible',to_regclass('storage.objects') is not null),
  ('membresias_base',to_regclass('public.miembros_club') is not null)
) x(control,ok)
order by control;

-- El hardening base también debe seguir sano. Debe devolver 0.
select count(*) as controles_multiclub_030_no_ok
from public.app_multiclub_audit_v030()
where not has_club_id or not rls_enabled or not tenant_index or direct_client_dml;

-- Debe devolver 0. Si hay filas, detener 032 y resolver 031 primero.
select count(*) as controles_finanzas_no_ok
from public.app_finance_receipts_audit_v031()
where estado<>'OK';
