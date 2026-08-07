# Android · Urban Warriors 1.2

## Incluido

El proyecto `android/` contiene una aplicación WebView con:

- branding, iconos y splash de Urban Warriors;
- aplicación web integrada en el APK;
- acceso a Supabase por HTTPS;
- selector de imágenes/PDF para justificantes;
- botón atrás;
- permiso de notificaciones Android 13+;
- canal local `urban_warriors_alerts`;
- versión `1.3.0`, `versionCode 6`.

## Preparar contenido

```bash
npm run android:prepare
```

## Compilar APK de prueba

Requisitos: Java 17, Android SDK 35 y Gradle compatible.

```bash
cd android
gradle assembleDebug
```

Salida:

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

El workflow `.github/workflows/android-debug.yml` también genera el APK de prueba.

## APK definitivo firmado

1. Crea un keystore fuera del repositorio.
2. Configura `signingConfigs.release` usando variables o secretos.
3. No subas el keystore ni sus contraseñas al repositorio.
4. Ejecuta `gradle assembleRelease`.
5. Conserva siempre el mismo keystore para poder actualizar la app instalada.

## Push con la aplicación cerrada

La PWA tiene integración FCM preparada en `web/js/push.js`. El APK WebView incluye alertas locales, pero el push nativo en segundo plano requiere añadir Firebase Android (`google-services.json`, plugin Google Services y servicio de mensajería) o migrar el envoltorio a Capacitor. Esa integración necesita el proyecto Firebase definitivo antes de compilar la versión de producción.

## Workflow firmado incluido

`.github/workflows/android-release.yml` utiliza estos secretos de GitHub:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

El resultado se entrega como artefacto `app-release.apk`. Después puede publicarse en GitHub Releases o en el hosting elegido.
