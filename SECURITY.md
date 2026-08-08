# Seguridad · Urban Warriors 2.0.0-rc.1

## Controles aplicados

- RLS y modelo multi-club existentes se conservan.
- El frontend no contiene `service_role`.
- La publishable key de Supabase se usa únicamente como `apikey`.
- `Authorization` transporta el token de sesión real.
- No existe DML directo desde los repositorios.
- Las 37 mutaciones de negocio pasan por `app_mutate_v160`.
- Cada mutación usa `request_id` y valida la respuesta versionada.
- Los errores de Auth/PostgREST/RPC/Storage se propagan a la interfaz.
- Documentos y justificantes permanecen en buckets privados y se abren mediante URL firmada.
- Los permisos visuales se centralizan en `core/permissions.js`; el backend continúa siendo la autoridad final.
- `app_bootstrap_direccion` no se expone desde la aplicación.
- El Certification Runner solo está visible para Dirección.

## Límites deliberados

- La RC no modifica RLS, RPC ni migraciones del backend.
- La matriz de permisos de frontend refleja las RPC conocidas, pero el backend sigue validando asignaciones específicas de monitor, familia o socio.
- Los consentimientos existentes pueden leerse bajo las políticas del backend, pero no se ha inventado una nueva mutación v160 para modificarlos.
- La certificación automática no genera cuotas masivas ni registra cobros reales de forma automática para evitar efectos económicos sobre datos legítimos.

## Antes de declarar producción certificada

1. Ejecutar `npm run build`.
2. Ejecutar el Certification Runner contra el Supabase real desde localhost.
3. Revisar la exportación JSON de trazas/IDs.
4. Hacer un único deploy final.
5. Repetir un smoke corto en el dominio Netlify.
