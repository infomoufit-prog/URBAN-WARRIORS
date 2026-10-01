# KOMBAX R116 — Google Play Pilot Checklist

Fecha de preparación: 2026-10-01

## Binario

- Package/applicationId: `com.urbanwarriors.app`
- versionCode: `20169`
- versionName: `2.0.0-rc.13-r116-golden-pilot-freeze`
- compileSdk: `36`
- targetSdk: `36`
- Firebase `google-services.json`: presente
- Upload key: **no incluida**; debe configurarse localmente con la clave registrada en Play Console.

## Compilar

APK QA:

```bat
KOMBAX_R116_BUILD_ANDROID_QA.cmd
```

AAB Play + APK release firmada:

```bat
KOMBAX_R116_BUILD_ANDROID_PLAY.cmd
```

El preflight detiene el proceso si falta la firma.

## Play Console — piloto

Para distribuir a los testers puede utilizarse Prueba interna o Prueba cerrada. Si la cuenta de desarrollador es personal y fue creada después del 13/11/2023, el acceso posterior a producción exige una prueba cerrada con al menos 12 testers inscritos de forma continua durante 14 días.

Antes de subir:

- completar ficha de Store;
- revisar Data safety;
- confirmar URL pública de privacidad;
- confirmar URL de eliminación de cuenta;
- completar clasificación de contenido;
- completar App access si el reviewer necesita login/instrucciones;
- revisar declaraciones de menores/Child Safety cuando correspondan;
- seleccionar países/regiones de la prueba;
- añadir testers y compartir el enlace de opt-in;
- comprobar que el AAB usa versionCode 20169 y la upload key correcta.

## Política de API objetivo

Desde el 31/08/2026, nuevas apps y actualizaciones para móviles en Google Play deben orientarse a Android 16 / API 36 o superior. R116 usa API 36.

## Nota de preparación

El código está listo para compilación. En el entorno de empaquetado no se pudo producir el APK/AAB porque Gradle necesitó descargar su distribución/dependencias y la JVM no tenía salida de red. Esto no es un error del proyecto; la compilación debe ejecutarse en el PC/Android Studio con conexión y la upload key del titular.
