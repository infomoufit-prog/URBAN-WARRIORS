# KOMBAX RC13 build 20077 · Owner Access Validation

Fecha: 2026-08-24

## Decisión aprobada

Acceso habitual a la Consola Owner:

1. Entrada oculta / ruta privada.
2. Cuenta KOMBAX que figure como Platform Admin/Owner activa.
3. Correo + contraseña normal.
4. Contraseña reciente validada por Supabase Auth.
5. Sesión administrativa KOMBAX temporal de 30 minutos, ligada al `session_id` real y auditada.
6. Sin OTP para consultar, moderar, verificar, gestionar clubes/cuentas, KOMBAX Analytics o mantenimiento ordinario.

Elevación crítica:

- OTP de 6 dígitos únicamente para operaciones excepcionalmente destructivas o de seguridad crítica.
- Actualmente conectado a ejecución irreversible de eliminación de cuenta y al gateway legacy de borrado profundo.
- Confirmación textual `ELIMINAR` se mantiene además cuando corresponda.

## Backend live

Migración aplicada:
- `kombax_owner_password_session_critical_otp_20077`

RPC nuevo:
- `app_kombax_platform_admin_password_session_v139()`
  - authenticated: EXECUTE
  - anon: NO
  - exige Platform Admin activo
  - exige método `password` reciente <= 600 s
  - crea sesión Owner 30 min
  - audita `admin.session.password`

Control crítico:
- `app_kombax_platform_critical_authorized_v139()`
  - no expuesto a authenticated/anon
  - requiere sesión Platform Admin activa + método `otp` reciente <= 600 s

Legacy password function:
- `app_kombax_platform_admin_password_complete_v110(uuid)` sigue sin EXECUTE para authenticated.

Eliminación de cuenta:
- `app_kombax_deletion_plan_v119` y `app_kombax_deletion_finalize_v119` están envueltos por elevación OTP crítica.

Borrados profundos legacy:
- `app_mutate_v160` requiere elevación OTP crítica salvo fixtures E2E sintéticos autorizados.

## Prueba reversible Supabase

Transacción sintética con JWT Owner y ROLLBACK final:

- password_session = true
- critical_without_otp = false
- critical_with_otp = true

PASS. Ninguna sesión sintética persistió.

## Frontend

`web/js/modules/platform-admin-access.js`
- retirada pantalla OTP del acceso cotidiano.
- copy: acceso oculto + cuenta Owner + contraseña + sesión temporal.
- botón: `Abrir Consola Owner`.

`web/js/core/backend.js`
- `beginPlatformAdminAccess()` usa `app_kombax_platform_admin_password_session_v139`.
- no solicita OTP en entrada normal.
- nuevos `beginPlatformCriticalAccess()` / `completePlatformCriticalAccess()` conservan OTP para step-up.

`web/js/modules/platform-admin.js`
- `Confirmación crítica Owner` solo en operación crítica.
- eliminación irreversible de cuenta: `ELIMINAR` + OTP crítico.
- readiness muestra `Protección crítica Owner`.

## QA

- `scripts/test-kombax-20077-owner-password-critical-otp.mjs`: PASS.
- regresión completa `npm test`: PASS.
- `npm run build`: PASS.
- output: `OK build 73 archivos · web = dist = Android`.
- Android preflight: 4/5; firma local pendiente como antes (`android/keystore.properties`).

## Deployment

- GitHub: NO TOCADO.
- Netlify frontend: NO TOCADO.
- Supabase: migración 139 aplicada y validada.

## Estado

PASS para la arquitectura Owner aprobada.
Pendiente QA E2E visual con credenciales Owner reales antes del deploy público: entrada oculta -> contraseña -> consola y, por separado, prueba de una elevación crítica OTP sin ejecutar destrucción real.
