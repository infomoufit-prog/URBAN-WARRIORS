# KOMBAX R117 — Android Studio / APK / AAB

## Abrir el proyecto

1. Descomprime/reunifica R117.
2. En Android Studio: **Open** y selecciona la carpeta `android` dentro del proyecto R117.
3. Configura Gradle JDK 17 o 21.
4. Deja que Android Studio sincronice/descargue Gradle 8.11.1 y dependencias.

`android/app/google-services.json` ya está incluido en el ZIP local R117 y corresponde a `com.urbanwarriors.app`. Está ignorado por Git para que Netlify no dependa de él.

## APK QA

Desde la raíz del proyecto en CMD:

```bat
KOMBAX_R117_BUILD_ANDROID_QA.cmd
```

Salida esperada:

`artifacts\KOMBAX_20170_R117_GOLDEN_PILOT_QA_DEBUG.apk`

También puede generarse desde Android Studio con la variante debug.

## AAB Google Play + APK release

La firma no se distribuye. Usa la upload key que ya tengas registrada en Google Play.

Opción A: copia `android\keystore.properties.example` a `android\keystore.properties` y completa los cuatro valores con tu clave local.

Opción B: usa variables de entorno `UW_KEYSTORE_PATH`, `UW_KEYSTORE_PASSWORD`, `UW_KEY_ALIAS`, `UW_KEY_PASSWORD`.

Después ejecuta:

```bat
KOMBAX_R117_BUILD_ANDROID_PLAY.cmd
```

Salidas esperadas:

- `artifacts\KOMBAX_20170_R117_GOLDEN_PILOT_GOOGLE_PLAY.aab`
- `artifacts\KOMBAX_20170_R117_GOLDEN_PILOT_SIGNED.apk`

Antes del build release el script ejecuta `android:preflight`, los gates legales y el gate Netlify.
