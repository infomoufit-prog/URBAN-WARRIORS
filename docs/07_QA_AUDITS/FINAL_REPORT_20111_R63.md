# KOMBAX 20.111 R63 — Informe final de auditoría e implementación

## Resumen ejecutivo
R63 consolida el endurecimiento comercial de Showcase y Events sobre la base R62.8 sin reescribir la arquitectura. Se mantiene Stripe Connect con direct charges en connected accounts y sin `application_fee` de KOMBAX. Se implementan guards de edad, evidencia contractual, seguridad/reporting de producto, casos comerciales, y plan trazable de cancelación/refund.

## Implementaciones principales
- Bloqueo comercial `<18` en Showcase y Events: frontend + RPC/backend checkout.
- Conservación de cuenta autónoma 16–17 fuera de funciones de compra.
- Versionado general Terms/Privacy alineado a `1.1.0-piloto` y hashes canónicos.
- Tablas `kombax_compliance.legal_documents` y `legal_acceptances`.
- Campos de trazabilidad/seguridad de producto y CE condicional.
- `commercial_cases` + timeline y RPC de reporte/cola.
- Reportar producto y evento desde UI sin duplicar botones de Social.
- Extensión del Seller Center con información de seguridad.
- Cancelación Events exige motivo, deshabilita ticketing y marca pedidos pagados `refund_pending`.
- Corrección del texto histórico que decía que Showcase no era ecommerce.
- Android incrementado a versionCode 20111/versionName R63.

## Stripe Connect — arquitectura auditada
- Sesiones de checkout creadas bajo la connected account mediante `Stripe-Account`.
- Modelo `direct`.
- `platform_fee = 0` y protección contra comisión transaccional KOMBAX.
- Webhook e idempotencia preexistentes conservados.
- R63 no cambia movimientos de dinero sin autorización.

## Tests
### PASS
- `test-kombax-20110-r62-4-stripe-connect-hardening.mjs`
- `test-kombax-20110-r62-5-showcase-events-ticketing.mjs`
- `test-kombax-20110-r62-7-marketplace-owner.mjs`
- `test-kombax-20110-r62-8-showcase-events-commercial.mjs`
- `test-kombax-20111-r63-commercial-compliance.mjs` — 18/18.
- `node scripts/build.mjs` — web = dist = Android.
- JS syntax checks de módulos modificados.

### LIMITACIONES DE ENTORNO, NO SILENCIADAS
- `npm test` completo se detiene en un test histórico que fija de forma literal `versionCode 20110`; R63 usa correctamente 20111. El log completo se incluye como `QA_R63_FULL_NPM.log`. Los tests funcionales dirigidos R62.4→R63 sí pasan.
- `./gradlew assembleDebug` no puede completarse en este entorno porque Gradle Wrapper necesita descargar Gradle 8.11.1 y el runtime no tiene acceso de red (`UnknownHostException: services.gradle.org`). Log incluido.
- Android release preflight: 4/5. Falta únicamente firma local porque `keystore.properties` y secretos no deben incluirse en el ZIP.

## Estado de cumplimiento
- TECHNICAL COMPLIANCE IMPLEMENTED: **sí para el alcance R63 en código estático**.
- LEGAL REQUIREMENTS MAPPED: **sí**.
- OPEN LEGAL REVIEW ITEMS: **sí**.

### Clasificación final
- TECHNICAL: **PARTIAL** — implementación y targeted QA PASS; pendiente aplicar migración en entorno de staging/real y E2E vivo.
- SHOWCASE: **CONDITIONAL**.
- EVENTS: **CONDITIONAL**.
- LEGAL COUNSEL REVIEW: **REQUIRED**.
- FISCAL REVIEW: **REQUIRED** (especialmente DAC7/calificación operador).

## Bloqueos/acciones antes de producción comercial pública
1. Completar razón social/datos fiscales/registrales/domicilio reales de KOMBAX SPAIN en Terms/Privacy. No se han inventado.
2. Aplicar migración R63 primero en Supabase de staging/preflight y ejecutar `verify_r63_commercial_compliance.sql`.
3. Ejecutar Stripe TEST E2E: vendedor/organizador, merchant display, recibos, statement descriptor, refund y dispute.
4. Confirmar con asesor legal alcance DSA/GPSR/P2B y, si corresponde, realizar Safety Gate/puntos de contacto externos.
5. Cerrar revisión fiscal DAC7.
6. Firmar localmente APK/AAB con keystore autorizado y ejecutar QA Android real.
7. Solo después: GitHub/Netlify/Google Play mediante flujo de release autorizado.

## Despliegues
No se ha realizado ningún despliegue a Supabase, GitHub, Netlify o Google Play y no se ha publicado ninguna APK/AAB.
