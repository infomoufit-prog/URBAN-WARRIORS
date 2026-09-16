# QA / Regresión · KOMBAX 20.101 R7

## Validaciones ejecutadas
- `node scripts/test-kombax-20042-gateway-brand.mjs` → PASS.
- `node scripts/test-kombax-20052-club-onboarding.mjs` → PASS.
- `node scripts/test-kombax-20100-brand-heroes.mjs` → PASS.
- `node scripts/test-kombax-20101-gateway-atmospheric-r7.mjs` → PASS.
- `npm test` (suite completa histórica + 20101 R6 + R7) → PASS.
- `node scripts/build.mjs` → PASS.
- Build determinista: `web = dist = android/app/src/main/assets/www`.
- Resultado build: 133 archivos sincronizados.

## Gates específicos R7
- Asset aprobado presente y >50 KB / <500 KB: PASS (184.038 bytes).
- Hero decorativo `aria-hidden`: PASS.
- `pointer-events:none`: PASS.
- Prioridad de carga de hero: PASS.
- Humo CSS rojo/azul en gateway: PASS.
- Humo compartido Social/Events/Showcase: PASS.
- Events > Social > Showcase en intensidad ambiental: PASS.
- `prefers-reduced-motion`: PASS.
- No GIF / vídeo / WebGL en el gateway: PASS.
- H1 gateway reducido y responsive: PASS.
- Breakpoints 620/420 px presentes: PASS.
- Bindings de acceso a club/perfil global intactos: PASS.
- Cache-busting R7 presente manteniendo identidad 20101: PASS.

## Backend
Esta fase no modifica backend. No procede ejecutar migraciones ni advisors por cambios de esquema, porque no hay cambios SQL/RLS/RPC/GRANT/Edge Function. La suite completa de contratos backend incluida en `npm test` sí se ha ejecutado y permanece en PASS.

## Incidencia de entorno de QA visual
Se intentó captura automatizada con Chromium headless en el contenedor, pero el binario no finalizó correctamente por dependencias DBus del entorno. No se declara una captura visual automatizada como validada. La comprobación visual final debe hacerse en navegador/Android real con el checklist adjunto; los gates estructurales y responsive sí están cubiertos por test estático R7.

## Estado
Candidato R7 válido para prueba local y móvil. No se ha realizado deploy.

## Firma local preservada
- `LOCAL_RELEASE_SIGNING/kombax-release.jks` presente.
- SHA-256 recalculado coincide con `LOCAL_RELEASE_SIGNING/KOMBAX_RELEASE_JKS_20097.sha256`.
- No se ha regenerado ni modificado la keystore.
