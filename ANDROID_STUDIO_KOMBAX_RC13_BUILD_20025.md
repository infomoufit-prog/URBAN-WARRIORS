# Android Studio · KOMBAX / Urban Warriors RC13 build 20025

## Identidad de actualización

- `applicationId`: `com.urbanwarriors.app`.
- `versionName`: `2.0.0-rc.13`.
- `versionCode`: `20025`.
- Alias conocido: `urban-warriors`.
- SHA-1 esperado: `27:B2:A6:45:22:65:26:E0:27:F0:D3:57:0B:CE:26:28:23:6D:53:BD`.
- SHA-256 esperado: `7D:AB:9B:B8:1A:56:A9:E2:E9:28:AF:B8:BA:10:2F:6F:01:3A:FC:73:B7:EC:F2:1E:BA:DB:D5:64:33:9E:F1:F3`.

El JKS y sus contraseñas no están en el ZIP. No crear otra clave ni cambiar el alias.

## Preparación local

1. Abrir la carpeta `android` en Android Studio.
2. Copiar el Firebase real como `android/app/google-services.json`.
3. Copiar `android/keystore.properties.example` como `android/keystore.properties`.
4. Indicar en `storeFile` la ruta al JKS existente `urban-warriors-realease.jks` y completar ambas contraseñas localmente.
5. Ejecutar desde la raíz: `node scripts/android-release-preflight.mjs`. Debe quedar todo en `OK`.

Los archivos locales están excluidos por `.gitignore`. No enviarlos en otro ZIP ni subirlos a Git/Netlify.

## Generación firmada

En Android Studio: **Build → Generate Signed App Bundle or APK**. Generar primero APK `release` para prueba física y después AAB `release` desde el mismo proyecto/JKS. Android Studio descargará las dependencias Gradle necesarias; este paquete no incluye Gradle Wrapper.

## Verificación obligatoria

1. Verificar la firma del APK con `apksigner verify --verbose --print-certs archivo.apk`.
2. Comparar SHA-1/SHA-256 con los valores esperados anteriores.
3. Con la build 20021 firmada instalada, instalar 20025 **sin desinstalar**. Si Android exige desinstalar, detenerse: la firma o el paquete no coinciden.
4. Probar login, sesión conservada, notificaciones, asistencia, recibo, cambio de club, KOMBAX Social, Showcase, safe areas, atrás y navegación de tres botones.
5. Probar FCM en primer plano, segundo plano y app cerrada.

No se afirma que APK/AAB estén validados hasta completar estos pasos en el ordenador y dispositivo reales.
