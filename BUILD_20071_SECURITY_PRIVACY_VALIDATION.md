# KOMBAX RC13 build 20071 · VALIDACIÓN DE SEGURIDAD, PRIVACIDAD Y PILOTO

Fecha: 2026-08-23
Base preservada: build 20070 PILOT_READINESS
Estado global: **NO-GO PUBLICACIÓN / CANDIDATA TÉCNICA LOCAL**

## Resultado técnico

| Control | Estado | Evidencia |
|---|---|---|
| Fuente 20070 preservada / 20071 en copia | PASS | directorio de trabajo separado |
| Owner OTP/MFA | PASS técnico | password + challenge + OTP; password-only revocado |
| Readiness MFA real | PASS | migración 127: build 20071 + `owner_mfa`; no confunde existencia de RPC con permiso efectivo |
| Android WebView/bridge | PASS estático | externos fuera de WebView; bridge restringido al origen interno |
| Android CAMERA | PASS | permiso eliminado |
| Deep links Android | PASS estático | `kombax.es`/`www`; preserva parámetros de invitación |
| Mi club push obligatorio | PASS backend | trigger v120; categorías internas forzadas a true |
| Privacidad push financiero | PASS backend/Android | FCM genérico + `VISIBILITY_PRIVATE` |
| `notification-dispatch` v10 | PASS operativo | cron posterior al despliegue responde HTTP 200 repetidamente |
| `payment-reminders` v7 | PASS operativo | ejecución posterior al despliegue HTTP 200 |
| Eliminación de cuenta | PASS arquitectura/backend | Owner-only + executor JWT + Storage/Auth soft-delete + anonimización |
| Moderador separado de privacidad | PASS | no autoriza queue/plan/finalize de eliminación |
| Menores Social | PASS arquitectura/backend | tutor + safety reminder + revocation; 0 menores activos afectados |
| Chat privado <18 | PASS | permanece bloqueado |
| Denuncia de mensajes | PASS arquitectura/backend | evidencia `single_message`; sin SELECT directo al historial/evidencia |
| Normas Social 1.4 | PASS backend | EASI/CSAE/CSAM + menores + reportes |
| Oracle anónimo de códigos | PASS | `anon` revocado; flujo autenticado conservado |
| Runtime canonical `kombax.es` | PASS local | sin `urban01.netlify.app` en runtime generado |
| Recursos `/privacy` y `/child-safety` | PASS técnico | páginas y rutas creadas |
| Gate legal de publicación | PASS preventivo | `release:build` bloquea si quedan placeholders jurídicos/contacto |
| `npm run build` | PASS | regresión completa + generación |
| Paridad web/dist/Android | PASS | **71 archivos** |
| Secret scan | PASS | sin service role/private key/JKS/PEM/SMTP password embebido |
| Supabase advisors | REVISADO | avisos RLS/RPC revisados; funciones críticas revisadas tienen guards internos; leaked-password protection sigue desactivado |
| Backup tooling | PASS código | DB + Storage tools preparados, hashes y restore aislado |
| Backup export real | BLOCKED | faltan credenciales temporales/`pg_dump` en este entorno |
| Restore drill real | BLOCKED | requiere destino Supabase aislado y credenciales temporales |
| Email SMTP request acceptance | PASS técnico | Auth `/invite` y `/recover` devolvieron 200 tras corregir SMTP |
| Email E2E branded | REQUIERE USUARIO | no existe todavía evidencia de recepción real del correo KOMBAX de producción |
| Auth runtime canonical | PENDIENTE DEPLOY | logs reales siguen en frontend anterior por no desplegar 20071 |
| Política privacidad global final | REQUIERE USUARIO | faltan responsable, NIF/CIF, domicilio, contacto, bases/proveedores y DPO si aplica |
| Contacto seguridad infantil | REQUIERE USUARIO | falta nombre/función y correo público de seguridad |
| Android preflight | 4/5 | firma local pendiente; `keystore.properties` no se empaqueta |
| GitHub privado | PENDIENTE | no tocar antes de autorizar el siguiente paso |
| Netlify 20071 | PENDIENTE | no desplegar todavía |

## Supabase LIVE

Aplicado y verificado:
- 119 · privacidad/eliminación Owner-only.
- 120 · push Mi club obligatorio.
- 121 · consentimiento adulto para Social de menores.
- 122 · denuncia de mensaje con evidencia mínima.
- 123 · recordatorio de seguridad y revocación efectiva.
- 124 · normas Social 1.4 Child Safety.
- 125 · trigger guards de menores fuera de RPC público.
- 126 · validador histórico de códigos revocado para `anon`.
- 127 · readiness 20071 basado en postura MFA efectiva.

Edge Functions activas:
- `notification-dispatch` v10.
- `payment-reminders` v7.
- `account-deletion-executor` v2 (`verify_jwt=true`).

## Comprobaciones con datos reales

- Menores activos en Social: **0**.
- Usuarios 16–17 con cuenta vinculada en la base actual: **0**.
- Solicitudes de eliminación confirmadas al instalar el ejecutor: **0**.
- No se eliminó ni modificó de forma destructiva ninguna cuenta real durante QA.

## Gate de publicación

La build normal de desarrollo pasa. `npm run release:build` está diseñado para **fallar** mientras existan tokens legales `[[KOMBAX_*]]` en `/privacy` o `/child-safety`. Esto evita publicar accidentalmente una política incompleta.

## Nota de despliegue

El frontend público continúa siendo la versión anterior. Los logs Auth aún muestran referer `https://urban01.netlify.app/` porque **20071 no se ha desplegado**. La fuente 20071 ya usa `https://kombax.es`; la divergencia es intencional hasta autorizar GitHub/Netlify.
