# KOMBAX RC13 build 20049 · validación final Auth + recibos multi-club

Fecha de cierre técnico: 2026-08-19

## Alcance

Build 20049 incorpora exclusivamente los dos cambios funcionales finales solicitados antes del freeze:

1. Recuperación de contraseña mediante correo + código de 6 dígitos + cambio de contraseña.
2. Recibos financieros multi-club con identidad del club emisor y snapshot histórico de branding.

No se ha abierto una nueva arquitectura ni se han alterado las reglas de Social, Relaciones, permisos o continuidad de identidad aprobadas en 20048.

## 1. Recuperación de contraseña

### Cliente implementado

Flujo KOMBAX:

1. Usuario pulsa `¿Has olvidado tu contraseña?` / `He olvidado mi contraseña`.
2. Introduce su correo.
3. KOMBAX solicita recuperación mediante Supabase Auth `POST /auth/v1/recover`.
4. La respuesta visible es neutra para evitar enumeración de cuentas.
5. Usuario introduce el código de 6 dígitos recibido.
6. KOMBAX verifica `POST /auth/v1/verify` con `type: recovery`.
7. La sesión temporal de recuperación se usa únicamente para actualizar la contraseña en `PUT /auth/v1/user`.
8. KOMBAX revoca/cierra la sesión temporal y limpia el almacenamiento local.
9. Regresa al login normal con el correo preparado.

Contraseña nueva: mínimo 8 caracteres en este build.

### Superficies cubiertas

- Login del Club.
- Login global KOMBAX.
- Mismo módulo de recuperación reutilizable en ambos flujos.

### Anti-enumeración

La UI no confirma si un correo existe o no. Mensaje genérico:

> Si existe una cuenta con ese correo, recibirás un código de 6 dígitos para cambiar la contraseña.

### Plantilla alojada de Supabase

Se incluye:

- `supabase/auth_templates/recovery_otp_20049.html`
- `supabase/auth_templates/README_20049.md`

La plantilla usa `{{ .Token }}` para mostrar el OTP.

**Acción manual pendiente:** en el proyecto Supabase alojado, pegar esa plantilla en `Authentication → Email Templates → Reset password` y usar, por ejemplo, el asunto `Código KOMBAX para cambiar tu contraseña`.

El conector disponible en esta sesión no expone edición de plantillas Auth alojadas, por lo que esta configuración no se ha podido aplicar automáticamente.

### Evidencia de prueba Auth

- Test estático 20049: PASS.
- Test conductual REST con `fetch` controlado: PASS.
- Secuencia comprobada: `/recover → /verify (recovery) → /user → logout`.
- Se comprobó que el cambio de contraseña usa el Bearer de la sesión temporal de recuperación.
- Se comprobó limpieza final de sesión/localStorage.
- Usuarios Auth antes/después del trabajo: 3 → 3; no se creó ninguna cuenta de prueba.

**No se declara E2E de correo real**: el runtime local no dispone de resolución DNS externa y no se modificó la contraseña de ninguna cuenta real. El E2E definitivo requiere configurar la plantilla alojada y hacer una prueba manual con una cuenta real controlada.

## 2. Recibos multi-club

### Problemas corregidos

Antes de 20049 existían dos residuos Urban Warriors:

- fallback visual `urban-warriors-logo.png` cuando `clubes.logo_url` estaba vacío;
- numeración interna histórica `UW-AAAA-######` en el emisor de recibos.

La solución 20049 elimina la dependencia de Urban Warriors para clubes nuevos sin reescribir destructivamente el motor financiero estable.

### Migración Supabase

Aplicada en vivo:

- `20260819005526 · kombax_multiclub_receipt_branding_20049`
- fuente local: `supabase/migrations/096_kombax_multiclub_receipt_branding_20049.sql`

### Modelo de emisor

`clubes` incorpora `recibo_prefijo`.

`recibos_cuota` incorpora snapshot del emisor:

- `emisor_nombre`
- `emisor_logo_url`
- `emisor_cif`
- `emisor_email`
- `emisor_telefono`
- `emisor_direccion`
- `emisor_web`
- `emisor_prefijo`

El logo se captura en este orden:

1. `clubes.logo_url`
2. `perfiles_club_publicos.logo_url`
3. si no existe logo, frontend KOMBAX neutro; nunca Urban Warriors por defecto.

### Trazabilidad histórica

Los recibos existentes no se renumeran ni cambian importe/fecha/trazabilidad. Solo se completó su snapshot del emisor.

Los cuatro recibos reales existentes conservan exactamente:

- `UW-2026-000001`
- `UW-2026-000002`
- `UW-2026-000003`
- `UW-2026-000004`

Los cuatro tienen ahora `emisor_nombre=Urban Warriors`, `emisor_prefijo=UW` y snapshot del logo real del perfil público del Club.

### Emisiones futuras

Un trigger `BEFORE INSERT` captura el emisor por `club_id` y normaliza el número como:

`PREFIJO-AAAA-######`

Urban Warriors mantiene `UW` para continuidad. Cada Club recibe su propio prefijo estable; no hereda `UW`.

### Smoke transaccional real

Se realizó un smoke dentro de transacción:

- se reinsertó temporalmente un recibo con un número deliberadamente incorrecto;
- el trigger corrigió el número al prefijo/año/secuencia del Club;
- capturó nombre, logo y prefijo del emisor;
- se ejecutó `ROLLBACK`.

Estado final:

- recibos después del rollback: 4;
- recibos con snapshot de logo: 4;
- fixtures persistidos: 0.

### Seguridad financiera

Verificación post-096:

- `anon` no puede leer `recibos_cuota` directamente.
- helper de prefijo 096 sin EXECUTE para `anon/authenticated`.
- trigger 096 sin EXECUTE para `anon/authenticated`.
- todos los `SECURITY DEFINER` auditados mantienen `search_path` fijado.
- owner global, Relaciones privadas y documentos de verificación permanecen intactos.

Rollback 096 está deliberadamente bloqueado por trazabilidad financiera.

## 3. Regresión / build

- `npm test`: PASS, incluyendo toda la cadena histórica y 20049.
- `npm run build`: PASS.
- Builder: `web = dist = Android`.
- Archivos web: 63.
- Archivos dist: 63.
- Archivos Android assets: 63.
- Faltantes: 0.
- Extras: 0.
- Diferencias de contenido: 0.
- SHA agregado común de los tres árboles:
  `dde0d09ac4448cd80b95924222c80e620a0dfc8403ec205c46d5b2c48420e415`

Android preflight:

- applicationId estable: PASS.
- versionCode 20049: PASS.
- assets embebidos: PASS.
- Firebase: PASS.
- firma release local: PENDIENTE deliberadamente, al no distribuir JKS/keystore.properties.

Resultado Android: 4/5 por ausencia segura de material de firma.

## 4. Supabase Advisors

Security Advisor reejecutado tras 096:

- no aparece una exposición nueva específica de los helpers/triggers 096;
- permanecen avisos históricos de tablas deny-by-default/RPC y endpoints `SECURITY DEFINER` intencionados;
- `Leaked Password Protection` continúa desactivado.

Performance Advisor reejecutado:

- mantiene deuda histórica de FKs sin índice, RLS initplan, múltiples policies permisivas, índices sin uso y un índice duplicado;
- no se ha ejecutado una refactorización masiva en esta fase para evitar introducir riesgo justo antes del freeze.

## 5. Pendientes antes de declarar producción

1. Configurar la plantilla `Reset password` alojada de Supabase con `recovery_otp_20049.html`.
2. Hacer un E2E real: pedir código → recibir correo → verificar → cambiar contraseña → entrar con la nueva contraseña.
3. Activar `Leaked Password Protection` en Supabase Auth y repetir el smoke Auth.
4. Validación visual/manual final PC + móvil.
5. Mantener el hardening de rendimiento como fase separada.

## 6. No tocado

- GitHub: no push/commit/PR.
- Netlify: no deploy.
- APK/AAB release: no firmado/generado para publicación.
- Google Play: no publicación.
- JKS/keystore reales: no incluidos.

Estado: **20.049 FINAL CANDIDATE**, todavía no `PRODUCTION CERTIFIED` hasta completar la configuración Auth alojada y su E2E real.
