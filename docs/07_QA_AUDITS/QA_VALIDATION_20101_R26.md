# R26 · QA y validación

## Prueba dedicada
`scripts/test-kombax-20101-privacy-support-events-nav-r26.mjs`

Resultado: **24/24 PASS**.

Cobertura principal:
- email canónico de soporte;
- entradas UI Club/cuenta/perfiles;
- grants temporales, scopes y revocación;
- hash del código;
- claim service-role-only;
- aislamiento de gestión Club/perfil;
- tablas internas no legibles directamente por authenticated;
- preservación del Owner;
- disclosure de administración privilegiada;
- continuidad de filtros/scroll/cache Events;
- revalidación server de Events;
- cache bust R26.

## Regresión global
`TEST_RESULTS_20101_R26_FULL.log`: suite completa final **PASS**.
Incluye R22 30/30, R23 15/15, R25 24/24 y R26 24/24.

## Build/paridad
`BUILD_RESULTS_20101_R26.log`: `OK build 172 archivos · web = dist = Android`.
`PARITY_SHA256_20101_R26.json`: 172/172/172, missing 0, extra 0, different 0.

## Android
`ANDROID_PREFLIGHT_20101_R26.log`: 4/5. Firma local pendiente por ausencia deliberada de `android/keystore.properties`.
No se afirma APK/AAB firmada.

## Pendiente físico
- Sensación de navegación de Events en Android real tras la mejora R26.
- Prueba completa de creación/revocación desde la UI en dispositivo/PWA con una cuenta piloto real.
- Integración del agente IA/correo real con el claim service-role-only.
