# Arquitectura · Urban Warriors 2.0.0-rc.8

## Principio

RC8 amplía la RC7 certificada sin alterar el canal estable de persistencia. El frontend no contiene una vía paralela de escritura ni vuelve al store monolítico de la línea 1.x.

## Capas

1. `web/js/core/supabase.js`: Auth, PostgREST, RPC y Storage.
2. `web/js/core/backend.js`: contrato, sesión, mutación gobernada, diagnóstico y Storage.
3. `web/js/core/repositories.js`: acceso por dominio y limpieza física de ficheros.
4. `web/js/core/state.js`: estado UI mínimo.
5. `web/js/ui/*` + `web/js/modules/*`: experiencia por rol y listeners explícitos.

## Escritura

`UI → repository → backend.mutate() → app_mutate_v160 → respuesta verificada → lectura → render`

Toda mutación valida versión, operación y `request_id`. Las nuevas eliminaciones también pasan por el gateway.

## Backend RC8

`020_session_reservations_document_download_v164.sql` se aplica después de 019 y mantiene:

- backend `1.6.0`;
- schema epoch `160`;
- endpoint `app_mutate_v160`;
- operaciones históricas delegadas a `app_mutate_v160_legacy`;
- RLS/Auth como autoridad.

Añade operaciones de borrado total y limpieza editorial sin alterar migraciones 001–017.

## Dos niveles de ciclo de vida

**Seguro:** archivar/desactivar/dar de baja/cancelar, o eliminar solo si no hay dependencias.

**Destructivo:** solo Dirección, confirmado escribiendo `ELIMINAR`, y elimina dependencias gobernadas para la entidad seleccionada.

Los recibos como elemento individual siguen usando `Anular` en el flujo económico normal. El borrado total de un alumno, solicitado expresamente por Dirección, elimina su conjunto de datos financieros relacionado para permitir la destrucción completa del expediente.

## Limpieza de Storage

- `member-documents`: documentos privados de expediente.
- `justificantes-pago`: justificantes privados.
- `club-public-media`: publicaciones, material y branding.

La base de datos devuelve las rutas/URLs afectadas y el repository elimina los objetos físicos después de confirmar la mutación. Reemplazar una imagen también limpia la anterior.

## PWA / Android

- frontend: `2.0.0-rc.8`
- Android: `versionCode 20008`, `versionName 2.0.0-rc.8`
- Web, `dist` y assets Android se sincronizan mediante `scripts/build.mjs`.


## Reservas de sesión RC8

`reservas_sesion` representa intención previa de asistencia y no sustituye `asistencias` ni el check-in. Las escrituras pasan exclusivamente por `app_mutate_v160` mediante `sesion.reserva.confirmar` y `sesion.reserva.cancelar`. El backend valida pertenencia, matrícula activa, estado programado y aforo antes de confirmar.

## Descarga privada RC8

La UI no expone `member-documents` públicamente. `supabase.js` obtiene una URL firmada temporal, descarga el blob y `documents.js` / `portal.js` inician la descarga local. Abrir y descargar respetan las mismas RLS y visibilidad documental existentes.
