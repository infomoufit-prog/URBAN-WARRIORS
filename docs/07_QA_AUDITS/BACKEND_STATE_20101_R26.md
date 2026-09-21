# R26 · Estado backend verificado

Proyecto Supabase principal: `poggsobhtutbuagjiydc`.

## Aplicado físicamente
- `kombax_authorized_support_privacy_20101_r26`
- `kombax_authorized_support_pgcrypto_fix_20101_r26`

## QA runtime
- Creación/listado de autorización temporal probado dentro de transacción y revertido con `ROLLBACK`.
- Dirección de Club B puede gestionar soporte de Club B y no del Club A.
- `authenticated` puede llamar a list/create/revoke, sujetos a validación del sujeto dentro de la función.
- `authenticated` NO puede ejecutar `app_kombax_support_authorization_claim_v194`.
- `service_role` SÍ puede ejecutar claim.
- `authenticated` NO tiene SELECT directo sobre las dos tablas internas de soporte.
- Recuento final posterior a QA: 0 autorizaciones persistidas y 0 filas de auditoría de prueba.

## Advisors
Security Advisor ejecutado. Persisten advertencias globales/históricas y advertencias derivadas del patrón SECURITY DEFINER existente; no se declara `security clean`.

Performance Advisor ejecutado. Persisten múltiples FK sin índice, índices sin uso y el índice financiero duplicado histórico. R26 añade índices de soporte recién creados que aún aparecen como `unused` por no tener tráfico representativo. También aparecen FK de las nuevas tablas sin índice dedicado. No se ha ampliado R26 con optimización especulativa.
