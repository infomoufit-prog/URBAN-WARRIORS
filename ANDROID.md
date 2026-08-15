# Android · RC13 build 20020

## Identidad y actualización

- `applicationId`: `com.urbanwarriors.app`
- `namespace`: `com.urbanwarriors.app`
- `versionCode`: `20020`
- `versionName`: `2.0.0-rc.13`
- `minSdk`: `24`
- `compileSdk`: `36`
- `targetSdk`: `36`
- AGP: `8.10.1`
- Java source/target: `17`

La continuidad de actualizaciones exige mantener el mismo `applicationId` y la misma cadena de firma. El keystore **no se incluye** en el repositorio; la build release toma `UW_KEYSTORE_PATH`, `UW_KEYSTORE_PASSWORD`, `UW_KEY_ALIAS` y `UW_KEY_PASSWORD` del entorno.

## Contenido web embebido

`web` es la fuente. `npm run build` debe dejar idénticos:

- `web/`
- `dist/`
- `android/app/src/main/assets/www/`

El cambio temporal usado para pruebas LAN no forma parte del freeze: `scripts/serve.mjs` debe escuchar en `127.0.0.1`.

## Permisos relevantes

- Internet.
- Cámara.
- Notificaciones (`POST_NOTIFICATIONS`).
- `usesCleartextTraffic=false`.

## Build nativo pendiente

Este entorno de trabajo no contiene Android SDK ni Gradle Wrapper completo, por lo que la certificación nativa APK/AAB debe ejecutarse en Android Studio/CI con toolchain compatible. Para AGP 8.10.x se debe usar Gradle 8.11.1 o superior compatible, según la tabla oficial de Android. AGP 8.10.1 es la versión fijada por este candidato y soporta API 36. La documentación oficial sitúa el mínimo para API 36.0 en AGP 8.9.1; por tanto no se presenta 8.10.1 como mínimo universal, sino como la versión concreta certificada estáticamente en este proyecto.

Antes del freeze:
1. sincronizar proyecto Android;
2. compilar `assembleRelease` con firma real;
3. compilar `bundleRelease` para AAB;
4. instalar APK 20020 encima de la versión anterior sin desinstalar;
5. probar login, notificaciones, permisos, multimedia, navegación y foreground/background;
6. conservar hashes del APK/AAB finalmente certificados.

## Google Play

La configuración apunta a API 36 para anticipar el requisito de nuevas apps/actualizaciones desde el 31-08-2026. Aun así, la subida exige revisión final de Play Console, público objetivo, Data Safety, política de privacidad, UGC, seguridad infantil, credenciales de revisión y firma/Play App Signing.

## Icono / launcher build 20020

- iconos legacy regenerados sin el recuadro gris exterior;
- PWA añade iconos `maskable` 192/512;
- Android API 26+ usa `adaptive-icon` con fondo `#050608` y foreground propio;
- el objetivo es que el emblema ocupe el marco del launcher sin aparecer como un cuadrado dentro de un círculo.
