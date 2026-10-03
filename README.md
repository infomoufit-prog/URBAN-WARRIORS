# KOMBAX R118 · build 20177 · acceso único y estabilización FIX03

Base congelable procedente de GitHub main, commit 7dd7c7ed39df13bb67880685c7c2df875b43f267. Versión 2.0.0-rc.13-r118-pilot-stabilization-1; versionCode 20177; com.urbanwarriors.app; SDK 36.

Empieza por [LEEME_KOMBAX_20177_FIX03.md](LEEME_KOMBAX_20177_FIX03.md). FIX03 incorpora las dos tarjetas de entrada, el acceso único y el selector Mi cuenta con clubes y perfiles separados. Supabase ya tiene activadas las reparaciones Owner y de alta Club Piloto, el procesamiento periódico y la preferencia de idioma. El alta gratuita y el rechazo del quinto Club se comprobaron en la base real dentro de una transacción revertida. Las comprobaciones y límites figuran en [ESTABILIZACION_PILOTO_FIX02.md](ESTABILIZACION_PILOTO_FIX02.md). Stripe mantiene requisitos de activación pendientes; los pagos no están certificados. La compilación se comprueba localmente sin publicar ni hacer push.

Esta entrega no incluye Firebase Android, firma privada ni .git. Conserva los tuyos. Las notas de versiones anteriores que siguen son históricas y no describen los archivos privados incluidos en esta entrega.

## Historial conservado

> **BASE ACUMULATIVA ACTUAL:** KOMBAX R117 build 20174 · Pilot Hotfix 4 · Perfil Social / registro progresivo.

# KOMBAX R117 · build 20174 · Pilot Hotfix 4 · Perfil Social + registro progresivo

R117 es la entrega acumulativa corregida sobre R116 para el piloto 01/10/2026–15/11/2026. Conserva el onboarding gratuito, los 8 recorridos de perfil, el gate de publicación Social para Miembro/Practicante confirmado por club, Competidor verificable e independiente, Owner Command Center y el bloqueo público de precios durante el piloto.

Corrección principal R117: el gate web de Netlify ya no exige `android/app/google-services.json`. Firebase Android continúa siendo obligatorio y se valida únicamente en `android:preflight` y en los scripts Android. El ZIP local sí incluye el `google-services.json` existente para poder abrir y compilar el proyecto en Android Studio.

Versión runtime: `2.0.0-rc.13-r117-pilot-hotfix-4` · build/versionCode `20174` · package `com.urbanwarriors.app` · compileSdk/targetSdk `36`.

Scripts principales:
- `KOMBAX_R117_VERIFY_LOCAL.cmd`
- `KOMBAX_R117_BUILD_ANDROID_QA.cmd`
- `KOMBAX_R117_BUILD_ANDROID_PLAY.cmd`
- `KOMBAX_R117_DEPLOY_NETLIFY.cmd`
- `KOMBAX_R117_DEPLOY_SUPABASE_FUNCTIONS.cmd`

La firma Google Play no se incluye. Para AAB/APK release usa la upload key ya registrada mediante `android/keystore.properties` o variables `UW_*`.

## R117 build 20172 · Pilot Hotfix 2 · 03/10/2026

Base acumulativa derivada del build 20171. Corrige el contrato de creación de cuentas: la fecha de nacimiento privada es obligatoria y se transmite de extremo a extremo al Auth signup en todas las vías que crean una cuenta. Las cuentas históricas sin DOB se completan mediante un flujo privado de una sola vez, sin inventar fechas. Se alinea la taxonomía con Media y se mantienen intactas las reglas Perfil Social, Club Piloto sin autorización y continuidad Android.

Comandos Windows de esta base:
- `KOMBAX_R117_20172_VERIFY_LOCAL.cmd`
- `KOMBAX_R117_20172_DEPLOY_NETLIFY.cmd`
- `KOMBAX_R117_20172_BUILD_ANDROID_QA.cmd`
- `KOMBAX_R117_20172_BUILD_ANDROID_PLAY.cmd`

El backend piloto activo ya contiene los hotfixes. Consultar `KOMBAX_R117_20172_BACKEND_PILOT.txt` antes de usar Supabase CLI.

## R117 build 20171 · Pilot Hotfix 1 · 02/10/2026

Base acumulativa derivada de R117 build 20170 para estabilización del piloto.

Cambios canónicos: alta Club Piloto directa sin código; perfil Perfil Social independiente de membresía; Miembro/Practicante con álbum pero sin feed hasta confirmación de club; Espectador con perfil público básico sin álbum ni feed; red/contactos separados del permiso de publicación; vinculación miembro/familia mediante invitación/código opcional o solicitud + autorización del club; continuidad Android tras llamadas/multitarea; build/versionCode 20171.

Comandos Windows incluidos en raíz:
- `KOMBAX_R117_20171_VERIFY_LOCAL.cmd`
- `KOMBAX_R117_20171_DEPLOY_NETLIFY.cmd`
- `KOMBAX_R117_20171_BUILD_ANDROID_QA.cmd`
- `KOMBAX_R117_20171_BUILD_ANDROID_PLAY.cmd`

El backend piloto activo ya contiene los hotfixes. Consultar `KOMBAX_R117_20171_BACKEND_PILOT.txt` antes de intentar aplicar migraciones nuevamente.
