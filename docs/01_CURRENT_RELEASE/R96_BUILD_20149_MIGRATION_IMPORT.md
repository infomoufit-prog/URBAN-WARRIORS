# KOMBAX R96 · Importación asistida por lotes

## Cambios incluidos
- Habilita KOMBAX Migrations para clubes, además de federaciones y marcas.
- El análisis conserva filas estructuradas de alumnos, cargos y pagos, con referencias al archivo de origen.
- Añade una pantalla para revisar y corregir filas antes de confirmar.
- La importación del club requiere identidad autenticada, permiso de gestión/finanzas, caso MIGRATION propio y referencia a filas analizadas.
- Los alumnos se crean como prealta; los cargos como pendientes con avisos pausados; los pagos se registran pendientes de validación y no pueden exceder el saldo del cargo.
- La operación es idempotente por solicitud y por fila de origen; las repeticiones no duplican esos registros.

## Límites y revisión
El asistente devuelve hasta cinco filas por archivo analizado para ajustarse al tamaño de respuesta del plan. Los documentos se procesan por lotes. No se actualizan fichas existentes ni se activa a los alumnos automáticamente. Una persona responsable debe corregir y marcar cada fila revisada y confirmar la importación. Los pagos importados requieren conciliación humana en el club.

## Estado del despliegue
- Supabase Edge Function `kombax-assist-r38`: activa, versión 11.
- RPC de lectura de filas e importación: instaladas en el proyecto KOMBAX.
- Ningún archivo de cliente se importó durante el despliegue.

## Archivos principales
`web/js/modules/customer-operations.js`, `web/js/core/repositories.js`, `web/css/kombax-premium.css`, `supabase/functions/kombax-assist-r38/index.ts`, `supabase/migrations/20260925133000_kombax_migration_batch_import_r96.sql`.