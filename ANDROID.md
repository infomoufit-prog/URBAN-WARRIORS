# Android · KOMBAX / Urban Warriors RC13 build 20025

Este es el resumen Android vigente. El procedimiento operativo completo está en `ANDROID_STUDIO_KOMBAX_RC13_BUILD_20025.md`; los documentos con build 20018, 20019 o 20021 son evidencia histórica y no instrucciones para esta candidata.

## Identidad de actualización

- `applicationId` y `namespace`: `com.urbanwarriors.app`.
- `versionCode`: `20025`.
- `versionName`: `2.0.0-rc.13`.
- `minSdk`: 24; `compileSdk`/`targetSdk`: 36.
- AGP: 8.10.1; Java: 17.
- alias del JKS existente: `urban-warriors`.

La actualización exige el mismo paquete y la misma cadena de firma que la build 20021 instalada. El ZIP no contiene el JKS, contraseñas, `keystore.properties`, `google-services.json`, APK ni AAB.

## Web embebida

`web` es la única fuente. `node scripts/build.mjs` regenera y verifica:

- `web/`;
- `dist/`;
- `android/app/src/main/assets/www/`.

La compilación local certificada contiene 60 archivos idénticos en los tres destinos. Android mantiene `usesCleartextTraffic=false`, origen WebView HTTPS virtual, safe areas y navegación nativa.

## Firma local

Crear `android/keystore.properties` desde el ejemplo o usar las variables `UW_*`. Apuntar al JKS ya existente y no crear una clave nueva. El preflight debe pasar 5/5 después de añadir Firebase y firma.

La candidata solo queda aprobada cuando el APK y el AAB se generan desde el mismo estado, `apksigner` confirma los fingerprints documentados y la APK 20025 se instala encima de 20021 sin desinstalar.

## Estado honesto

Configuración y recursos Android: preparados estáticamente. Gradle, Firebase real, firma JKS, APK/AAB y dispositivo físico: pendientes del ordenador autorizado.
