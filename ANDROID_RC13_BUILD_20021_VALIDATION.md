# Validación Android RC13 build 20021

> **BASE HISTÓRICA DE ACTUALIZACIÓN.** No sustituye la validación física de build 20025 ni su guía Android vigente.

Fecha de preparación: 15/08/2026

## Alcance autorizado

- Base: `Urban_Warriors_RC13_MVP_build_20020_COMPLETE_FIXED.zip`.
- Destino: APK/AAB móvil Android.
- Sin cambios ni despliegues en Netlify.
- Sin cambios en Supabase.
- Sin escrituras en GitHub.
- Frontend y backend funcional congelados.

## Cambio de ejecución

`MainActivity` recibía los `WindowInsets` en píxeles físicos y los enviaba directamente a CSS. En dispositivos de alta densidad, el margen reservado se ampliaba artificialmente. Build 20021 divide los insets por la densidad de pantalla antes de establecer `--uw-native-safe-top` y `--uw-native-safe-bottom`.

No se han modificado las reglas CSS ni los archivos del frontend web. Los 51 archivos de `web/` coinciden byte a byte con la base build 20020 suministrada.

## Preparación de actualización

- `applicationId` conservado: `com.urbanwarriors.app`.
- `versionName` conservado: `2.0.0-rc.13`.
- `versionCode` incrementado: `20020` → `20021`.
- La firma admite `android/keystore.properties` local o las variables `UW_*`.
- El paquete excluye keystores, contraseñas, APK y AAB mediante `.gitignore`.
- Se incorpora `npm run android:preflight` para comprobar preparación sin mostrar secretos.

## Pruebas superadas

- Arquitectura y grafo de imports.
- Contrato backend RC13: 93/93.
- Regresiones RC4–RC12.
- Finanzas, material y recibos.
- Comunidad, imágenes y vídeo.
- Eventos y competiciones.
- Notificaciones accionables.
- Perfiles y seguridad social/UGC.
- Responsive de escritorio y móvil.
- Preparación estática Android/API 36.
- Corrección estática de densidad de insets.
- Menú lateral: mismo botón abre/cierra y desplazamiento táctil habilitado.
- Selector de imágenes: el formulario no se cierra al volver.
- Build determinista: 51 archivos idénticos entre `web`, `dist` y assets Android.

Resultado de la batería: **PASS**.

## Elementos locales pendientes antes de firmar

El ZIP no puede contenerlos por seguridad o porque pertenecen a la instalación local:

1. `android/app/google-services.json` real para Firebase/FCM.
2. Keystore original `.jks/.keystore` y sus credenciales.
3. Android SDK y Gradle compatible disponibles en Android Studio.

La compilación nativa firmada y la comprobación visual final deben hacerse en Android Studio. El entorno de preparación no dispone de Android SDK ni de la clave privada del propietario, por lo que no se afirma haber generado ni firmado una APK/AAB.

## Criterio de aprobación física

1. La APK 20021 se instala encima de la anterior sin desinstalarla.
2. La firma coincide y no aparece `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.
3. Cabecera y barra inferior dejan de presentar márgenes sobredimensionados.
4. Se valida menú, selector de imágenes, login, FCM y retorno desde segundo plano.
5. El AAB 20021 es aceptado por Play Console con la clave de subida correcta.
