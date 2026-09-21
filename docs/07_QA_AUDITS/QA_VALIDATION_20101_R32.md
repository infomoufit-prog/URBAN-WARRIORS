# QA Validation · KOMBAX 20.101 R32 · Pilot RC

## PASS automatizado
- Matriz de perfiles/capacidades R32: 36/36.
- Cross-profile/cross-tenant contractual: PASS.
- RLS dirigida R28-R31: PASS.
- DML directo en tablas nuevas: 0 grants para anon/authenticated.
- RPC sensibles R28-R31: `anon_execute=false`.
- Federación: frontera privada Club presente frontend/backend.
- Profesional Médico: clínica deshabilitada/ausente.
- Manager: delegación aceptada/revocable/expirable.
- Finanzas Profesionales: sin fake Club, sin cobro in-app, sin facturación fiscal completa.
- PWA cache R32: PASS.
- Regresión histórica: PASS.
- Build/paridad: 183/183/183, 0 mismatches.
- Smoke local HTTP: PASS.

## Smoke local ejecutado
`npm run dev` en localhost respondió HTTP 200 para:
- `/`
- `/social`
- `/events`
- `/service-worker.js`
- `/manifest.webmanifest`

Evidencia: `LOCAL_SMOKE_20101_R32.log`.

## Android
Preflight: 4/5.
PASS:
- `applicationId com.urbanwarriors.app`
- `versionCode 20101`
- assets www presentes
- Firebase presente

Único PENDIENTE:
- firma local (`android/keystore.properties`), deliberadamente no empaquetada.

Se intentó `assembleRelease` sin firma. El wrapper heredado no era ejecutable directamente en Linux y se reintentó con `bash gradlew`; Gradle no pudo descargar `gradle-8.11.1` por ausencia de resolución DNS en este entorno. No se clasifica como fallo de la app. Log: `ANDROID_ASSEMBLE_RELEASE_20101_R32.log`.

## Gate manual pendiente por definición
El Plan Maestro exige pruebas Android reales. Este entorno no dispone de dispositivo/emulador Android ni descarga Gradle. Por ello R32 se etiqueta **Pilot RC listo para validación local**, no producción Android certificada.

El propietario debe hacer:
- abrir Android en Android Studio/entorno Gradle provisionado;
- configurar firma local;
- generar APK/AAB signed;
- instalar la APK en dispositivo real;
- validar identidad/perfiles, navegación, Social, Showcase, Events, Mi Club y Mi actividad;
- solo después hacer push/deploy manual si decide aprobar el candidato.
