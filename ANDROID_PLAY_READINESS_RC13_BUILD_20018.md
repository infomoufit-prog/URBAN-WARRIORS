# Android / Google Play readiness · Urban Warriors RC13 build 20018

## Estado de esta auditoría

Este documento certifica únicamente la **preparación estática del proyecto** que puede verificarse en el repositorio. No afirma que exista todavía una APK/AAB release compilada, firmada, instalada o aceptada por Google Play.

## Identidad y continuidad de actualización

- `applicationId`: `com.urbanwarriors.app`
- `namespace`: `com.urbanwarriors.app`
- `versionCode`: `20018`
- `versionName`: `2.0.0-rc.13`
- `minSdk`: `24`
- `compileSdk`: `36`
- `targetSdk`: `36`
- Android Gradle Plugin: `8.10.1`
- Java source/target: `17`

La continuidad desde instalaciones anteriores depende de conservar el mismo `applicationId` y la misma cadena de firma. La configuración no incrusta secretos ni un keystore en el repositorio.

## Firma release

La build release obtiene la firma únicamente desde variables del entorno:

- `UW_KEYSTORE_PATH`
- `UW_KEYSTORE_PASSWORD`
- `UW_KEY_ALIAS`
- `UW_KEY_PASSWORD`

No se ha generado ni compartido una clave de firma desde este entorno. La clave real debe conservarse fuera del repositorio y debe verificarse que corresponde a la usada en las instalaciones que se quieran actualizar sin desinstalar.

## API 36 y toolchain

El proyecto está configurado con `compileSdk 36` y `targetSdk 36`. Google Play exige API 36 o superior para nuevas apps y actualizaciones a partir del 31 de agosto de 2026. La documentación oficial de Android sitúa en AGP 8.9.1 el mínimo para API 36.0; este candidato fija AGP 8.10.1. Para AGP 8.10, la tabla oficial indica Gradle 8.11.1 como mínimo.

Este contenedor dispone de Java 21, pero **no dispone de Android SDK, Gradle instalado ni Gradle Wrapper completo en el proyecto**. Por tanto, no es posible certificar honestamente aquí `assembleRelease` ni `bundleRelease`.

Puerta nativa pendiente:

1. abrir/sincronizar el proyecto en Android Studio o CI con Android SDK 36;
2. usar un toolchain compatible con AGP 8.10.1 y Gradle 8.11.1+;
3. compilar `assembleRelease` con la firma real;
4. compilar `bundleRelease`;
5. registrar SHA-256 de APK y AAB;
6. instalar 20018 encima de la build previa sin desinstalar;
7. probar login, notificaciones, cámara/multimedia, foreground/background y navegación del sistema.

## Seguridad Android ya fijada en código

- `usesCleartextTraffic=false`.
- Permiso de Internet.
- Permiso de cámara.
- `POST_NOTIFICATIONS` declarado para Android moderno.
- Safe areas del WebView conservadas para el layout móvil.
- Assets Android sincronizados desde la misma fuente web: la build local final demuestra `web = dist = android/app/src/main/assets/www`.
- `scripts/serve.mjs` vuelve a `127.0.0.1`; no se conserva el cambio LAN temporal a `0.0.0.0`.

## UGC / Comunidad

La RC13 build 20018 incorpora en código las piezas necesarias para gobernar contenido generado por usuarios:

- aceptación explícita y versionada de Normas de Comunidad antes de publicar;
- denuncia de publicaciones;
- denuncia de perfiles;
- bloqueo/desbloqueo de usuarios;
- bandeja de denuncias para moderación;
- ocultación de publicaciones;
- estados de revisión/resolución;
- suspensión/reactivación del acceso a la futura Comunidad General con motivo y auditoría;
- motivo específico de seguridad relativo a menores.

Esto responde técnicamente a la necesidad de contar con mecanismos in-app de denuncia/bloqueo y moderación. **No equivale a una certificación de cumplimiento de Google Play**: la política se evalúa también por funcionamiento real, términos publicados, actuación operativa, clasificación de audiencia y declaraciones de Play Console.

## Edad y menores

El modelo implementado distingue:

- autorregistro autónomo como alumno del club: **16+**, validado también en backend;
- futura Comunidad General: alta opcional y separada, solo rol alumno en esta fase, con edad tomada del socio activo verificado por el club;
- umbral social configurable por club con suelo técnico de producto **14**;
- familia/tutor no puede activar la identidad social general;
- fecha de nacimiento permanece privada y no se publica en la identidad social.

Antes de publicar en Google Play se debe decidir y declarar correctamente el público objetivo. Si la experiencia social incluye usuarios de 14–15 años, la revisión de políticas de menores/seguridad infantil debe cerrarse de forma explícita en Play Console y en la operativa real de moderación.

## Privacidad / Data Safety

La aplicación crea cuentas desde la propia app y trata datos personales. Antes de Google Play quedan pendientes como puertas de publicación:

- política de privacidad pública y coherente con el comportamiento real;
- formulario **Data Safety** completo, incluyendo Supabase, Firebase/FCM y cualquier SDK que recoja/procese datos;
- revisión de permisos y datos recogidos;
- definición pública de retención y eliminación;
- comprobación de requisitos de eliminación de cuenta.

Google Play exige un flujo de eliminación si la app permite crear cuentas: ruta in-app y recurso web para solicitar eliminación. Esa función **no se declara implementada/certificada en esta RC13 build 20018**. Debe diseñarse antes de la publicación atendiendo a qué registros administrativos/financieros deban conservarse por obligaciones legítimas y cuáles deben eliminarse o disociarse.

## Play Console pendiente

No están certificados desde el código:

- cuenta de desarrollador y sus requisitos de testing;
- ficha de tienda, screenshots, descripción y clasificación de contenido;
- público objetivo;
- Data Safety;
- URL de privacidad;
- recurso web de eliminación de cuenta;
- Child Safety Standards / declaraciones aplicables;
- credenciales/instrucciones para revisión;
- Play App Signing / clave de subida;
- revisión y aprobación final de Google Play.

## Conclusión

**Preparación estática Android: PASS. Publicación Google Play: PENDIENTE. Build nativa release: PENDIENTE.**

El código queda deliberadamente listo para dar el siguiente paso sin afirmar que ese paso ya se ha realizado.
