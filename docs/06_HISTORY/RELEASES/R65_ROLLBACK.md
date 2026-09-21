# KOMBAX R65 · Rollback / contingencia

R65 introduce operaciones financieras reales y tablas de auditoría. No se recomienda un rollback destructivo de base de datos.

## Frontend

Si una incidencia visual/operativa impide el piloto, volver a desplegar el artefacto frontend R64.4 build 20115. No borrar tablas ni datos R65.

## Edge Functions

Puede revertirse temporalmente la exposición UI de Finance/Refunds desplegando las funciones/cliente anteriores, manteniendo los ledgers R65. Los webhooks deben conservar compatibilidad con refunds ya emitidos.

## Supabase

Las ocho migraciones R65 ya forman parte del historial. La contingencia segura es **forward-fix**, no `DROP` de ledgers ni eliminación de movimientos financieros. Cualquier corrección debe añadirse como una nueva migración posterior.

## Reembolsos

Nunca reintentar manualmente un refund cambiando IDs o eliminando filas para saltarse la idempotencia. Usar el mismo `request_id`/flujo de R65 o reconciliar el estado con Stripe antes de una acción manual.

## Android

R64.4 y R65 comparten el mismo applicationId. Para pruebas, instalar únicamente builds con `versionCode` coherente. R65 usa `versionCode 20116`.
