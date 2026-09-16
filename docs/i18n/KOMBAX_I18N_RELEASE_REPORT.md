# KOMBAX · Internationalization final release report

## Base
KOMBAX 20124 R73 SHOWCASE_REPUTATION_EVENTS_COMMUNITY_COMPLETION_PILOT_FREEZE, evolucionada acumulativamente mediante B01 F01–05, B02 F06–10, B03 F11–15 y B04 F16–20.

## Resultado
- Arquitectura i18n permanente sobre un único producto/código.
- 8 locales soportados: ES, EN, FR, PT, IT, DE, TH, FIL.
- ES/EN habilitados para piloto.
- 475 claves maestras y 475/475 no vacías en los 8 locales.
- Fallback selected → EN → ES.
- Selector/detección/persistencia y `preferred_locale` preparados.
- Intl centralizado para fecha/hora/número/porcentaje/moneda/pluralización.
- Social/Showcase/Events/Assist/Migrations/email/push/documentos/legal integrados en el alcance B03.
- Legal separa locale/jurisdiction/legal_version.
- QR/tickets/Stripe IDs/rutas/user content permanecen invariantes.

## QA final automatizado
- npm test PASS.
- build PASS: 399 archivos; web = dist = Android.
- i18n validator PASS.
- B04 test PASS 20/20.
- legal gate PASS.
- Android preflight 4/5 por firma local ausente.

## Gates externos honestos
- Visual runtime autenticado FR/DE/TH y resto de idiomas ocultos requiere dispositivo/navegador real.
- Android firmado requiere keystore local.
- Stripe/email/push reales requieren entornos/credenciales correspondientes.
- Thai dynamic finance PDF conserva fallback inglés por limitación de fuente estándar actual.

## Deploy
No se ha hecho push GitHub, deploy Netlify, publicación Google Play ni despliegue Supabase automático.
