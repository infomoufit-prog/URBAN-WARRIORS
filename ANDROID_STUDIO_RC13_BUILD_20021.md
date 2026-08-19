# Urban Warriors · Android Studio · RC13 build 20021

> **HISTÓRICO.** Para generar la candidata actual usar únicamente `ANDROID_STUDIO_KOMBAX_RC13_BUILD_20025.md`.

Esta entrega es una variante exclusivamente móvil de la RC13 web build 20020 congelada. No requiere ni autoriza cambios en Netlify, Supabase o el repositorio desplegado.

## Qué contiene

- `applicationId`: `com.urbanwarriors.app`
- `versionName`: `2.0.0-rc.13`
- `versionCode`: `20021`
- `compileSdk` / `targetSdk`: `36`
- AGP: `8.10.1`
- Java: `17`
- frontend embebido completo en `android/app/src/main/assets/www`
- corrección de áreas seguras para pantallas Android de alta densidad
- configuración de firma por archivo local o variables de entorno

## 1. Descomprimir y abrir

1. Descomprime el ZIP en una ruta corta y fuera de OneDrive, por ejemplo `C:/UrbanWarriors/RC13_20021`.
2. En Android Studio pulsa **Open**.
3. Abre únicamente la carpeta `android` contenida en el ZIP.
4. Selecciona el JDK integrado de Android Studio o Java 17 cuando se solicite.
5. Espera a que finalice la sincronización de Gradle.

El proyecto original no contiene un Gradle Wrapper completo. Android Studio debe usar o descargar una distribución compatible con AGP 8.10.1. No copies un Wrapper de otro proyecto sin verificar su versión.

## 2. Firebase antes de compilar

Para conservar las notificaciones push, copia el archivo real utilizado por la APK anterior en:

`android/app/google-services.json`

El ZIP contiene solamente `google-services.json.example`; no sirve para una release real. Si falta el archivo real, la aplicación puede compilar y funcionar, pero Firebase/FCM no quedará registrado correctamente.

## 3. Conservar la misma firma

Una actualización debe firmarse con la misma clave que la APK anterior o con la clave de subida registrada en Google Play.

Busca en tu ordenador un archivo con extensión `.jks` o `.keystore`. No crees uno nuevo hasta comprobar si la aplicación anterior ya fue firmada o subida a Play Console.

Para comprobar un almacén existente sin compartir contraseñas:

```text
keytool -list -v -keystore "C:/ruta/urban-warriors-upload-key.jks"
```

En Google Play Console, compara la huella SHA-256 con la clave de subida mostrada en **Integridad de la aplicación**. Si todavía nunca se subió un AAB, conserva de forma permanente la clave elegida para la primera publicación.

## 4. Método sencillo de firma local

1. Copia `android/keystore.properties.example` como `android/keystore.properties`.
2. Edita únicamente la copia local:

```properties
storeFile=C:/RUTA/SEGURA/urban-warriors-upload-key.jks
storePassword=TU_CONTRASENA_LOCAL
keyAlias=TU_ALIAS
keyPassword=TU_CONTRASENA_DE_CLAVE
```

Usa barras `/` en las rutas de Windows. `keystore.properties`, `.jks` y `.keystore` están excluidos para impedir que se incorporen por accidente al repositorio.

Desde una terminal situada en la raíz del proyecto puedes comprobar la preparación sin mostrar las credenciales:

```text
npm run android:preflight
```

También puedes ejecutar la tarea `signingStatus` desde el panel Gradle de Android Studio.

## 5. Generar APK firmada de prueba

1. Ve a **Build > Generate Signed App Bundle or APK**.
2. Selecciona **APK**.
3. Selecciona el módulo `app`.
4. Elige el mismo `.jks/.keystore`, alias y contraseñas anteriores.
5. Selecciona `release` y activa las firmas recomendadas por Android Studio.
6. Genera la APK.
7. Instálala encima de la APK anterior, sin desinstalarla.

Si Android muestra `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, la clave utilizada no coincide con la instalación anterior. No desinstales la versión anterior hasta resolver y verificar la firma.

## 6. Generar AAB para Google Play

Repite el asistente y selecciona **Android App Bundle**. Usa exactamente la misma clave de subida. El AAB debe mostrar `versionCode 20021`, superior al build 20020.

## 7. Validación física obligatoria

- La instalación actualiza la versión anterior sin perder datos locales.
- Login y cambio de perfiles.
- Cabecera ajustada bajo la barra de estado.
- Navegación inferior próxima a la barra del sistema, sin franja sobredimensionada.
- Botón hamburguesa abre y cierra el menú.
- Menú lateral se desplaza verticalmente.
- Selector de imágenes vuelve al formulario sin cerrarlo.
- Cámara, archivos y permisos.
- Recepción y apertura de una notificación push.
- Paso a segundo plano y regreso a primer plano.
- Navegación Android mediante tres botones y mediante gestos, cuando sea posible.

## 8. Archivos que nunca deben publicarse

- `android/keystore.properties`
- cualquier `.jks` o `.keystore`
- contraseñas o capturas que las muestren

Conserva dos copias cifradas del keystore y anota de forma segura su alias y contraseñas. Sin esa clave no se puede mantener la cadena normal de actualizaciones.
