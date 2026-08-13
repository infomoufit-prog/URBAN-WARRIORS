# Android

## Base

- Package: `com.urbanwarriors.app`.
- Versión congelable: RC12, `versionCode 20016`, `versionName 2.0.0-rc.12`.
- Firma: usar exclusivamente el keystore definitivo existente y el alias `urban-warriors`.
- Los secretos de firma se introducen localmente; nunca se almacenan en Git ni en documentación.

## Release B — safe areas

- El WebView trabaja edge-to-edge de forma explícita.
- Android obtiene los insets de barras del sistema y `displayCutout` sin incluir el teclado.
- Los valores se comunican al frontend mediante `--uw-native-safe-top` y `--uw-native-safe-bottom`.
- CSS combina los valores nativos con `env(safe-area-inset-*)` para mantener compatibilidad PWA.
- Cabecera, menú lateral, contenido, navegación inferior, login, toast y modales reservan las zonas seguras.

## Firma release

- Abrir la carpeta `android/` en Android Studio y esperar la sincronización de Gradle.
- Colocar el `google-services.json` real en `android/app/` para conservar FCM.
- Usar el keystore definitivo existente y el alias `urban-warriors`; nunca crear otro si la APK actualizará una instalación previa.
- En **Build > Generate Signed Bundle / APK**, elegir **APK**, módulo `app`, variante `release`, introducir keystore, alias y contraseñas y activar las firmas V1 y V2.
- El resultado se genera normalmente en `android/app/build/outputs/apk/release/app-release.apk`.

## Prueba física pendiente

En Pixel 8 deben comprobarse: cabecera, hamburguesa, usuario, campana, navegación inferior, formularios largos, modales, perfil, `Cerrar sesión`, teclado y rotación bloqueada en vertical.
