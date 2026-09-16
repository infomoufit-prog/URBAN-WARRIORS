# KOMBAX 20.101 R33 · QA validation

## PASS verificado
- Suite completa JS/regresión.
- R33 52/52.
- Build y paridad triple.
- Smoke local PWA.
- Supabase real aplicado y probado.
- Privacidad cross-federation.
- Equipo federativo y capabilities.
- Edge Function `invite-email` v4 ACTIVE con JWT.

## Pendiente de validación externa
- Compilación Android real en este entorno: el wrapper intentó descargar Gradle 8.11.1 y falló por DNS `services.gradle.org`.
- Firma release: no existe `android/keystore.properties` dentro del paquete por seguridad.
- APK/AAB signed y prueba física WebView: deben generarse con la clave local existente del proyecto.
- Google Play: no existe un conector Play Console en esta sesión; además un upload requiere AAB firmado y confirmar que versionCode 20101 no esté ya usado.
- Netlify: la cuenta conectada solo expone `learninglabnexo`; no se ha desplegado KOMBAX sobre un sitio no identificado como KOMBAX.
