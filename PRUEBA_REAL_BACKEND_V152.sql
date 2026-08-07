-- URBAN WARRIORS 1.5.2 — PRUEBA REAL DEL BACKEND
-- Ejecutar en Supabase SQL Editor DESPUÉS de aplicar 012_operational_integrity_v152.sql.
-- No usa Netlify y no deja datos de prueba si finaliza correctamente.

select jsonb_pretty(
  public.app_autotest_operativo_v152(
    '11111111-1111-4111-8111-111111111111'::uuid
  )
) as resultado;

-- RESULTADO CORRECTO:
-- Debe contener "ok": true y "version": "1.5.2".
-- Si cualquier operación real falla, PostgreSQL devuelve un ERROR con el punto exacto
-- (grupo, alumno, publicación, pago, Storage/policy, etc.) y revierte la llamada.
