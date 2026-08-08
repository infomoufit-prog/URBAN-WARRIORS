# RC3 · Corrección de idempotencia del certificador E2E

## Hallazgo real
La segunda ejecución de la certificación alcanzó `sesion.guardar` y PostgreSQL rechazó la alta por la restricción única `(club_id, codigo_acceso)`. La RC2 usaba siempre `codigo_acceso = E2E`; una ejecución anterior que se detuvo antes de la limpieza dejó esa sesión en la base.

## Corrección
El certificador genera ahora un `codigo_acceso` distinto en cada ejecución a partir de `Date.now()`. No se modifica la lógica funcional de Sesiones ni el backend.

La prueba queda reejecutable incluso cuando una ejecución previa se corta antes de la fase de limpieza.

## Backend
Sin cambios en Supabase, migraciones, RPC, RLS ni contrato 1.6.0.
