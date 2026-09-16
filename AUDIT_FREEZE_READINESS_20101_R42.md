# KOMBAX 20101 R42 — Freeze Readiness Audit

Fecha: 2026-09-05
Estado: **PASS como candidata de congelación técnica / READY FOR PRE-QA**
Autorización de datos reales: **NO AUTORIZADA todavía**

## 1. Linaje y criterio de preservación

R42 se ha reconstruido **directamente sobre R40**, que se considera la única base candidata íntegra. R41 **no se ha adoptado como base**: se ha utilizado exclusivamente como fuente de dos deltas de interfaz previamente aislados y revisados.

Esto evita heredar regresiones o modificaciones no deseadas de R41 y preserva la lógica, migraciones, backend, permisos y comportamiento funcional ya auditados en R40.

## 2. Únicos cambios portados desde R41

### A. KOMBAX explainer — viewport móvil seguro
- Se elimina el forzado móvil `width: 100vw; height: 100dvh`.
- Se adopta `width:100%`, `height:auto`, `min-height:100dvh`.
- Se añade protección horizontal (`max-width:100%`, `overflow-x:clip`).
- Se normaliza `box-sizing` y `min-width:0` para descendientes.
- Cabecera, cuerpo y acciones respetan `env(safe-area-inset-left/right)`.
- En escritorio se mantiene el comportamiento contenido de altura completa.

Objetivo: evitar recortes/overflow lateral y mejorar visualización en móviles con safe areas, barras de navegador y WebView.

### B. Shell estructural neutro KOMBAX
- El watermark/fondo estructural del shell global deja de depender del logo del club/tenant.
- El shell usa la marca KOMBAX mediante `getBrandLogoUrl()`.
- El branding del club se conserva donde corresponde funcionalmente: identidad del club, portadas, perfiles públicos, tienda y superficies específicas del tenant.

Objetivo: mantener KOMBAX como eje visual neutral entre clubes/federaciones sin borrar la identidad del club en sus espacios propios.

## 3. Evidencia automática

| Gate | Resultado |
|---|---|
| Test específico R42 | **PASS — 24/24** |
| Regresión completa `npm test` | **PASS — exit 0** |
| Suite heredada R40 | **PASS — 74/74** |
| Build web/dist/Android | **PASS — exit 0** |
| Paridad web = dist = Android | **PASS — 189/189/189, 0 diferencias SHA** |
| Android preflight | **PASS** |
| Inmutabilidad backend R40→R42 | **PASS** |
| Supabase R40→R42 | **162/162 archivos, byte-identical** |
| Netlify R40→R42 | **1/1 archivo, byte-identical** |
| Functions R40→R42 | **1/1 archivo, byte-identical** |
| Escaneo patrones de secretos | **PASS — 910 archivos, 0 hallazgos** |

Archivos de evidencia principales:
- `FULL_TEST_LOG_20101_R42.txt`
- `BUILD_LOG_20101_R42.txt`
- `ANDROID_PREFLIGHT_20101_R42.txt`
- `PARITY_20101_R42.json`
- `BACKEND_IMMUTABILITY_R40_TO_R42.json`
- `SECRET_PATH_AUDIT_20101_R42.json`
- `scripts/test-kombax-20101-r42-freeze-candidate.mjs`

## 4. Backend y migraciones

R42 **no modifica backend, Supabase, Netlify Functions ni migraciones respecto a R40**. No se ha realizado ninguna mutación del Supabase vivo durante esta reconstrucción.

Por tanto, los dos cambios de R42 son de presentación/shell y no alteran el modelo de datos ni los contratos backend.

## 5. Interpretación correcta del PASS

Este PASS significa:

> El código es apto para ser tratado como **freeze candidate** y entregado a la fase PRE-QA/estabilización con Work y revisión humana.

No significa:

> “Producción aprobada”, “ciberseguridad aprobada” o “entrada de datos personales reales autorizada”.

## 6. Gates pendientes antes del piloto con datos reales

1. QA manual en dispositivos representativos Android/iOS y navegadores/WebView, incluyendo safe areas, orientación y tamaños extremos.
2. Pruebas completas de rol, sesión, cambio de identidad y aislamiento multitenant con datos sintéticos similares a producción.
3. Captura y revisión verificable de **Supabase Security Advisors** del proyecto vivo y revisión específica de RLS/GRANT/RPC efectivos.
4. Revisión de ciclo de autenticación y sesión: expiración, revocación, recuperación, invitaciones, OTP/MFA cuando aplique.
5. Revisión de mínimo privilegio y tratamiento de claves/variables entre local, CI, Netlify y Supabase.
6. Evidencia de backup/restore, recuperación, rollback y procedimiento de migraciones para el piloto.
7. Revisión humana del código y del diff R40→R42.
8. Revisión de logging, monitorización, auditoría e incidente/respuesta.
9. Sign-off de ciberseguridad antes de incorporar información personal real de clubes/miembros.

### Nota sobre Supabase vivo
Se intentó consultar evidencia de advisors de seguridad durante este cierre, pero **no se obtuvo una captura verificable utilizable para anexarla a este artefacto**. Por rigor, el gate se mantiene como **PENDIENTE** y no se infiere ningún resultado.

## 7. Decisión de auditoría

**R42: READY FOR PRE-QA / FREEZE CANDIDATE = PASS.**

**PILOTO CON DATOS REALES = BLOCKED hasta completar los gates vivos/manuales/ciberseguridad anteriores.**
