# Runbook Supabase previo a APK y deploy

Estado actual confirmado: migraciones 023–028 aplicadas y verificadas; 029–030 pendientes.

La secuencia completa, Edge Functions, CRUD/RLS, Android y la puerta de Netlify están en `PREDEPLOY_EXECUTION.md`.

## Orden obligatorio

1. Ejecutar `supabase/verification/preflight_029_video.sql`; exige 6/6 `OK`.
2. Aplicar 029 y ejecutar `supabase/verification/verify_029_video.sql`; exige 7/7 `OK`.
3. Ejecutar `supabase/verification/preflight_030_multiclub.sql`; exige 10/10 `OK`.
4. Aplicar 030 y ejecutar `supabase/verification/verify_030_multiclub.sql`; exige 7/7 `OK`.
5. Ejecutar `supabase/verification/final_audit_023_030.sql`; exige 10/10 `OK`.
6. Desplegar y probar `notification-dispatch` y `payment-reminders` con backup y logs.
7. Ejecutar `supabase/verification/pre_apk_backend_health.sql`.
8. Completar matriz CRUD/RLS con roles reales antes de generar APK.

Cada paso se detiene ante el primer error. No se fusiona GitHub ni se despliega Netlify durante este runbook.
