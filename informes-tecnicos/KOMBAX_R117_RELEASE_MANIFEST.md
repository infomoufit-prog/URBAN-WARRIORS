# KOMBAX R117 — Golden Pilot Netlify + Android Ready

Fecha: 2026-10-01

- Release: `2.0.0-rc.13-r117-netlify-android-ready`
- Build / Android versionCode: `20170`
- Android package: `com.urbanwarriors.app`
- compileSdk / targetSdk: `36`
- Baseline acumulativa: R116 Golden Pilot Freeze

## Corrección principal

El gate de Netlify ya no exige `android/app/google-services.json` durante `npm run release:build`. El archivo sigue siendo obligatorio para Android y lo valida `scripts/android-release-preflight.mjs`.

Se verificó el build de Netlify simulando un checkout de GitHub sin `google-services.json`: PASS.

## Funcionalidad preservada

- Cuenta gratuita neutral y 8 recorridos de perfil.
- Miembro/Practicante sin publicación Social hasta membresía activa confirmada por club.
- Competidor directo o evolución desde Miembro manteniendo verificación documental.
- Perfiles institucionales y verificaciones existentes.
- Precios públicos ocultos durante piloto con mensaje `No disponible hasta lanzamiento`.
- Owner Command Center, alertas, informes y push acumulativos.

## QA

- R117 exact release test: 10/10 PASS.
- Netlify release gate: 61 PASS, 5 P2 I18N históricos conocidos, 0 fallos nuevos.
- Build: 621 archivos alineados web = dist = Android assets.
- Smoke HTTP local sobre `dist`: `/`, `/js/app.js`, `/privacy.html`, `/terms.html`, `/delete-account.html`, `/child-safety.html` => HTTP 200.
- Android preflight: 7/8; único pendiente externo: upload key/firma local.
- `google-services.json` local presente y asociado a `com.urbanwarriors.app`.

## Android

La fuente queda preparada para Android Studio, APK QA y AAB Google Play. La firma release no se incluye en el ZIP. Debe usarse la upload key existente mediante `android/keystore.properties` o variables `UW_*`.

En el entorno de empaquetado no se completó `assembleDebug` porque Gradle necesitó descargar `gradle-8.11.1` y dicho entorno no dispone de salida de red. El fallo observado fue `UnknownHostException: services.gradle.org`, no un error de Gradle/configuración del proyecto.

## Scripts R117

- `KOMBAX_R117_VERIFY_LOCAL.cmd`
- `KOMBAX_R117_BUILD_ANDROID_QA.cmd`
- `KOMBAX_R117_BUILD_ANDROID_PLAY.cmd`
- `KOMBAX_R117_DEPLOY_NETLIFY.cmd`
- `KOMBAX_R117_DEPLOY_SUPABASE_FUNCTIONS.cmd`
