# KOMBAX 20.101 R33 · Google Play readiness

Estado: preparado para generación local de APK/AAB, no publicado desde esta sesión.

Bloqueos reales:
1. Firma release externa no incluida por seguridad.
2. Este entorno no pudo descargar Gradle 8.11.1.
3. No hay integración Play Console disponible en esta sesión.
4. Antes de subir, comprobar si `versionCode 20101` ya está utilizado en Google Play. Si lo está, Play exige un versionCode superior; no se ha modificado automáticamente.

Objetivos locales esperados una vez configurada la firma:
- `android/app/build/outputs/apk/release/app-release.apk`
- `android/app/build/outputs/bundle/release/app-release.aab`
