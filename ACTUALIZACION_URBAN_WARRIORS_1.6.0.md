# Actualización Urban Warriors 1.6.0 — ronda final de guardado

## Orden obligatorio

1. Ejecutar `015_mutation_governance_v160.sql` en Supabase SQL Editor **una sola vez**.
2. Solo si termina con `Success. No rows returned`, subir el parche 1.6.0 a GitHub.
3. Netlify ejecutará automáticamente los tests de gobernanza antes de copiar `web/` a `dist/`; un fallo impide publicar.
4. Cuando el deploy sea `Published`, abrir la web. Al iniciar sesión, la app verifica automáticamente el contrato backend 1.6.0 antes de permitir cualquier escritura.

## No hacer

- No ejecutar otra vez migraciones 001–014.
- No subir versiones 1.5.x mezcladas con este parche.
- No copiar `data-store.js` antiguo ni backups.
- No hacer un deploy antes de que 015 haya terminado correctamente.

## Qué protege esta versión

La interfaz ya no puede escoger una RPC antigua o escribir directamente una tabla. Todas las operaciones productivas pasan por `app_mutate_v160`, con JWT de usuario, control de membresía, permisos por operación, tipos resueltos en PostgreSQL e idempotencia.
