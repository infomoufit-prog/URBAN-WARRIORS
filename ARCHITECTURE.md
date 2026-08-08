# Arquitectura · Urban Warriors 2.0.0-rc.1

## Decisión principal

El backend 1.6.0 se mantiene y el frontend se ha reconstruido. No se reutiliza el store monolítico ni el dispatcher global de la línea 1.6.x.

## Capas

### 1. Cliente Supabase
`web/js/core/supabase.js`

Único lugar del frontend que realiza `fetch` a Auth, PostgREST, RPC y Storage. La clave `sb_publishable_*` se envía como `apikey`; `Authorization` usa el access token real.

### 2. Backend adapter
`web/js/core/backend.js`

Gestiona autenticación, restauración de sesión, contrato backend, diagnóstico, trazas y la única ruta de mutación.

Cada escritura verifica previamente el contrato y después valida:
- `ok`
- `backend_version`
- `operation`
- `request_id`

### 3. Repositories
`web/js/core/repositories.js`

Consultas específicas por dominio. No existe una recarga global de todas las tablas tras cada operación.

### 4. Estado
`web/js/core/state.js`

Estado mínimo de sesión, ruta, error, diagnóstico, trazas y certificación. La UI no marca una operación como guardada antes de recibir confirmación.

### 5. UI y módulos
`web/js/ui/components.js` y `web/js/modules/*`

Los formularios tienen listeners de `submit` directos. La secuencia es:

`submit → reportValidity → Guardando… → await repository → Guardado ✓ / error visible`

## Persistencia

Todas las escrituras de negocio pasan por:

`app_mutate_v160(p_operation, p_payload, p_request_id)`

El frontend contiene referencias a las 37 operaciones del contrato v160 entre repositorios y operaciones de bootstrap/push.

## Lecturas

Las lecturas usan PostgREST con RLS. Se cargan únicamente las colecciones necesarias para la pantalla actual.

## Storage

- `member-documents`: documentos privados de socios.
- `justificantes-pago`: justificantes privados de pago, con URL firmada temporal.
- medios públicos existentes del backend se mantienen.

## PWA

El service worker 2.0 no guarda en caché HTML, JavaScript, CSS, config ni el propio service worker. Solo cachea activos estáticos no críticos. Al activarse elimina caches antiguos.

## Android

Web y Android comparten exactamente el mismo runtime generado por `scripts/build.mjs`.

La WebView sirve los assets desde:
`https://appassets.androidplatform.net/`

Esto permite módulos ES sin depender de `file://`. La app Android no registra el service worker sobre ese host virtual.

## Compatibilidad

- frontend: `2.0.0-rc.1`
- build: `20001`
- backend: `1.6.0`
- schema epoch: `160`
