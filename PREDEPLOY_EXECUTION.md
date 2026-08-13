# Paquete previo a Netlify y APK

## Estado certificado de RC12 (build 20016)

- Base de código: RC10 restaurada, consolidada en RC11 y ampliada de forma conservadora en RC12.
- Supabase confirmado: migraciones 023–030 aplicadas y auditoría final 10/10 `OK`.
- RC12: código y build estáticos aprobados; la migración 031 y su prueba transaccional deben ejecutarse antes de Netlify.
- Auditor multiclub: todos los recursos `true/true/true/false`.
- Edge Functions `notification-dispatch` y `payment-reminders`: desplegadas y verificadas; push real recibido en Android.
- Cron y Vault: configurados y comprobados sin exponer secretos.
- Corrección incluida: el formulario ya no se cierra al regresar del selector de imágenes.
- Pendiente: aplicar/verificar 031, generar la APK firmada, instalarla y realizar la prueba física final.
- Prohibido durante este proceso: fusionar el PR, publicar Netlify o generar una candidata Play.

Los nombres de archivo no se pegan en el editor SQL. Se abre el archivo, se copia **su contenido completo** y se ejecuta una sola vez. Ante `FALLO` o error se detiene el proceso; no se prueba el archivo siguiente.

## Fase 1 · Migración 029 — vídeo y portadas

| Orden | Archivo | Tipo | Resultado requerido |
|---:|---|---|---|
| 1 | `supabase/verification/preflight_029_video.sql` | Solo lectura | 6/6 `OK` |
| 2 | `supabase/migrations/029_community_video_covers.sql` | Migración | `rollback_ok=true`, `bucket_50mb_ok=true` |
| 3 | `supabase/verification/verify_029_video.sql` | Solo lectura | 7/7 `OK` |

Después se prueba desde la aplicación: publicación de vídeo válido, rechazo de más de 15 segundos, rechazo de más de 50 MB, portada automática, portada manual por Gestor/Coordinación, eliminación de publicación y limpieza de los tres paths de Storage. El límite de 15 segundos se valida en frontend; 50 MB, 1080p y paths también quedan gobernados por backend.

Rollback disponible: `supabase/rollbacks/029_community_video_covers.sql`. Solo se ejecuta si la migración terminó y una prueba bloqueante falla. Es conservador: restaura el gateway y no destruye columnas ni archivos.

## Fase 2 · Migración 030 — multiclub, RLS e índices

| Orden | Archivo | Tipo | Resultado requerido |
|---:|---|---|---|
| 1 | `supabase/verification/preflight_030_multiclub.sql` | Solo lectura | 10/10 `OK` |
| 2 | `supabase/migrations/030_multiclub_rls_performance.sql` | Migración | tabla de auditoría sin valores inseguros |
| 3 | `supabase/verification/verify_030_multiclub.sql` | Solo lectura | 8/8 `OK`; cada recurso `true/true/true/false` |

030 cierra `INSERT/UPDATE/DELETE` directos del cliente en todos los recursos incluidos en su auditoría multiclub. Las escrituras de la aplicación deben seguir pasando por `app_mutate_v160`. Esto es intencionado, pero exige la matriz CRUD real antes de aprobar.

Rollback disponible: `supabase/rollbacks/030_multiclub_rls_performance.sql`. Restaura los privilegios capturados por 030 y las políticas anteriores.

## Fase 3 · RC12 — desglose financiero y recibos

Orden obligatorio en SQL Editor:

| Orden | Archivo | Tipo | Resultado requerido |
|---:|---|---|---|
| 1 | `supabase/verification/preflight_031_finance_receipts.sql` | Solo lectura | Todas las filas `OK` |
| 2 | `supabase/migrations/031_finance_receipts_breakdown.sql` | Migración | Auditor final sin `FALLO` |
| 3 | `supabase/verification/verify_031_finance_receipts.sql` | Solo lectura | Todos los orígenes con `pagados_sin_recibo=0` |
| 4 | `supabase/verification/test_031_receipts_transactional.sql` | Prueba reversible | 7/7 `OK`; termina en `ROLLBACK` |

La prueba confirma un recibo único al completar una cuota, otro al completar material con su concepto e importe propios, y ningún recibo final para un pago parcial. Rollback conservador disponible en `supabase/rollbacks/031_finance_receipts_breakdown.sql`.

## Fase 4 · Auditoría SQL conjunta — completada hasta 030

Ejecutar `supabase/verification/final_audit_023_030.sql`. Resultado requerido: 10/10 `OK`.

Este control demuestra estructura, cadena de gateways y aislamiento; todavía no certifica la experiencia real.

## Fase 5 · Edge Functions antes de Android — completada

Orden obligatorio:

1. Confirmar en Supabase que existen, sin mostrarlos en el chat, `UW_CRON_SECRET` y `FIREBASE_SERVICE_ACCOUNT_JSON`. `SUPABASE_URL` y la clave secreta de Supabase son proporcionadas por el entorno de la función.
2. Guardar una copia/exportación de la versión desplegada de `notification-dispatch`; después desplegar `supabase/functions/notification-dispatch/index.ts`, invocar manualmente con `x-uw-cron-secret` y revisar respuesta y logs.
3. Guardar una copia/exportación de `payment-reminders`; después desplegar `supabase/functions/payment-reminders/index.ts`, ejecutar una prueba controlada con `force=true`, `club_id` y una fecha de pruebas, y revisar logs/historial.

Nunca se comparte el valor del secreto. Una respuesta `deployed` no aprueba la función. Debe haber invocación correcta, logs limpios y ausencia de duplicados.

Después se ejecuta `supabase/verification/pre_apk_backend_health.sql`. En la consulta de duplicados deben aparecer 0 filas; en el auditor tenant, todas las filas deben ser `true/true/true/false`.

## Fase 6 · Matriz CRUD/RLS real

Se prueba con cuentas reales, no desde el rol administrador del SQL Editor:

| Recurso | Dirección | Coordinación | Secretaría | Alumno | Familia |
|---|---|---|---|---|---|
| Comunicaciones | Crear/leer/editar/eliminar | Según rol | Según rol | Solo lectura autorizada | Solo lectura autorizada |
| Comunidad | Publicar/leer/eliminar | Publicar y portada | Según rol | Leer/publicar según RC10 | Leer según autorización |
| Finanzas | Crear/pagar/validar/leer | Solo permiso asignado | Registrar/validar | Solo sus cargos/pagos | Solo vinculados |
| Material | Crear/validar/eliminar | Registrar/validar | Registrar/validar | Solicitar pendiente | Ver vinculado |
| Push | Generar/administrar | Según rol | Según rol | Registrar token propio | Registrar token propio |

Por cada operación se confirma `SELECT`, `INSERT`, `UPDATE` y `DELETE` cuando corresponda. Si una escritura RC10 deja de funcionar, se detiene la release y se identifica si falló el gateway, RLS o el frontend; no se añaden parches acumulativos.

## Fase 7 · Android Studio y APK física — siguiente paso

Solo cuando Supabase, Edge Functions y CRUD/RLS estén aprobados:

1. Abrir `android/` del mismo repositorio, colocar localmente el `google-services.json` real y sincronizar los assets mediante `npm run build`. Verificar que `web`, `dist` y assets Android coinciden.
2. Usar `versionCode 20016` y `versionName 2.0.0-rc.12`; generar APK release con el keystore existente y alias `urban-warriors`. Las contraseñas se introducen localmente y nunca se guardan en Git.
3. Instalar sobre la versión anterior en Pixel 8 y certificar arranque sin crash, login/logout/persistencia, safe top/bottom, teclado, permiso Android, registro/renovación token y push con app abierta, segundo plano y cerrada.

Después se repite en APK: comunicaciones, Comunidad texto/imagen/vídeo/portadas/paginación, Finanzas, material, perfiles y roles. `BUILD SUCCESSFUL` no equivale a aprobación.

## Puerta final antes de Netlify

Netlify continúa bloqueado hasta que estén simultáneamente en estado `pruebas reales superadas`:

- auditoría SQL 023–031 y prueba transaccional de recibos;
- Edge Functions y logs;
- matriz CRUD/RLS;
- APK Pixel 8 y push en los tres estados;
- regresión web local y paridad de assets;
- commit y punto de rollback identificables.

Solo entonces se autoriza fusionar el PR y realizar **un único despliegue de producción** en Netlify. Tras ese despliegue se validan Ctrl+F5, PWA, login, Comunidad, comunicaciones, Finanzas y materiales. El AAB para Google Play se genera después de esa certificación, con el mismo keystore.
