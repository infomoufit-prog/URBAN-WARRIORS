# KOMBAX R117 · build 20170 · Golden Pilot Netlify + Android Ready

R117 es la entrega acumulativa corregida sobre R116 para el piloto 01/10/2026–15/11/2026. Conserva el onboarding gratuito, los 8 recorridos de perfil, el gate de publicación Social para Miembro/Practicante confirmado por club, Competidor verificable e independiente, Owner Command Center y el bloqueo público de precios durante el piloto.

Corrección principal R117: el gate web de Netlify ya no exige `android/app/google-services.json`. Firebase Android continúa siendo obligatorio y se valida únicamente en `android:preflight` y en los scripts Android. El ZIP local sí incluye el `google-services.json` existente para poder abrir y compilar el proyecto en Android Studio.

Versión runtime: `2.0.0-rc.13-r117-netlify-android-ready` · build/versionCode `20170` · package `com.urbanwarriors.app` · compileSdk/targetSdk `36`.

Scripts principales:
- `KOMBAX_R117_VERIFY_LOCAL.cmd`
- `KOMBAX_R117_BUILD_ANDROID_QA.cmd`
- `KOMBAX_R117_BUILD_ANDROID_PLAY.cmd`
- `KOMBAX_R117_DEPLOY_NETLIFY.cmd`
- `KOMBAX_R117_DEPLOY_SUPABASE_FUNCTIONS.cmd`

La firma Google Play no se incluye. Para AAB/APK release usa la upload key ya registrada mediante `android/keystore.properties` o variables `UW_*`.
