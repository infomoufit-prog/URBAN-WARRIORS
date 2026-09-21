# QA · KOMBAX 20.101 R23 · Urban Fighter Image Recovery

## Causa raíz
Los datos backend y los 10 WEBP estaban correctos, pero R22 conservaba tres puntos frágiles: el resolver podía priorizar una URL demo recibida del backend sobre el asset empaquetado según runtime; el servidor local CMD no declaraba MIME WEBP/SVG; y el cache bust multimedia seguía identificado como R21.

## Evidencia backend
Evento `urban-warriors-interclub-jiu-jitsu-palafolls-demo`:
- participantes: 10
- participantes con `foto_url`: 10
- combates: 5
- combates con foto A y B: 5
- Main Event foto A: presente
- Main Event foto B: presente

No se aplicó ninguna migración R23 porque el backend no estaba roto.

## Evidencia assets/local HTTP
Los 10 retratos Urban existen en `web`, `dist` y `android/app/src/main/assets/www`.
Los 10 responden en el servidor local con:
- HTTP 200
- `Content-Type: image/webp`

El fallback SVG responde HTTP 200 con `image/svg+xml`.

## Tests
- `npm run test:20101:r23`: PASS 15/15
- R17 fighter hardening actualizado semánticamente: PASS
- R18 routing/realism: PASS
- R21 framing: PASS 30/30
- R22 performance/scale: PASS 30/30
- `npm test`: PASS · exit 0

## Build
- `node scripts/build.mjs`: PASS
- resultado: `171 archivos · web = dist = Android`
- paridad SHA-256:
  - web vs dist: missing 0 / extra 0 / diff 0
  - web vs Android assets: missing 0 / extra 0 / diff 0

## Android
Preflight: 4/5.
- package: PASS
- versionCode 20101: PASS
- assets/www: PASS
- Firebase: PASS
- firma local: PENDIENTE porque `android/keystore.properties` no se incluye con secretos.

## Validación visual
La corrección está validada técnica y funcionalmente por referencias, binarios y servidor local. La aceptación visual final en el Chrome/PC y APK Signed del usuario permanece PENDIENTE hasta su prueba física.
