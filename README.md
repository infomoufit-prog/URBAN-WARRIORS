# KOMBAX R117 · build 20171 · Pilot Hotfix · Continuidad + Elite Social + vinculación fácil

R117 es la entrega acumulativa corregida sobre R116 para el piloto 01/10/2026–15/11/2026. Conserva el onboarding gratuito, los 8 recorridos de perfil, el gate de publicación Social para Miembro/Practicante confirmado por club, Competidor verificable e independiente, Owner Command Center y el bloqueo público de precios durante el piloto.

Corrección principal R117: el gate web de Netlify ya no exige `android/app/google-services.json`. Firebase Android continúa siendo obligatorio y se valida únicamente en `android:preflight` y en los scripts Android. El ZIP local sí incluye el `google-services.json` existente para poder abrir y compilar el proyecto en Android Studio.

Versión runtime: `2.0.0-rc.13-r117-pilot-hotfix-1` · build/versionCode `20171` · package `com.urbanwarriors.app` · compileSdk/targetSdk `36`.

Scripts principales:
- `KOMBAX_R117_VERIFY_LOCAL.cmd`
- `KOMBAX_R117_BUILD_ANDROID_QA.cmd`
- `KOMBAX_R117_BUILD_ANDROID_PLAY.cmd`
- `KOMBAX_R117_DEPLOY_NETLIFY.cmd`
- `KOMBAX_R117_DEPLOY_SUPABASE_FUNCTIONS.cmd`

La firma Google Play no se incluye. Para AAB/APK release usa la upload key ya registrada mediante `android/keystore.properties` o variables `UW_*`.

## R117 build 20171 · Pilot Hotfix 1 · 02/10/2026

Base acumulativa derivada de R117 build 20170 para estabilización del piloto.

Cambios canónicos: alta Club Piloto directa sin código; perfil Elite Social independiente de membresía; Miembro/Practicante con álbum pero sin feed hasta confirmación de club; Espectador con perfil público básico sin álbum ni feed; red/contactos separados del permiso de publicación; vinculación miembro/familia mediante invitación/código opcional o solicitud + autorización del club; continuidad Android tras llamadas/multitarea; build/versionCode 20171.

Comandos Windows incluidos en raíz:
- `KOMBAX_R117_20171_VERIFY_LOCAL.cmd`
- `KOMBAX_R117_20171_DEPLOY_NETLIFY.cmd`
- `KOMBAX_R117_20171_BUILD_ANDROID_QA.cmd`
- `KOMBAX_R117_20171_BUILD_ANDROID_PLAY.cmd`

El backend piloto activo ya contiene los hotfixes. Consultar `KOMBAX_R117_20171_BACKEND_PILOT.txt` antes de intentar aplicar migraciones nuevamente.
