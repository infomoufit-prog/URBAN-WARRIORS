# KOMBAX R104.4 — corrección de compilación Android

Fecha: 28/09/2026. Base: R104.3, build 20156.

Android Studio informó: `KombaxTerminalManager.java:66: variable sink might not have been initialized`.

## Causa y corrección

El inicializador de campo `tokenProvider` contenía una lambda que leía `sink`, un campo `final` asignado en el constructor. El compilador Java detecta esa referencia antes de que la asignación sea definitiva. Se cambió el inicializador a una referencia a método (`this::requestConnectionToken`) y se trasladó el cuerpo anterior a ese método. El constructor, la solicitud de token, el evento emitido y la interfaz Stripe Terminal se preservan.

Se aplicó el cambio tanto a la fuente acumulativa como a la copia extraída en Desktop que se estaba abriendo en Android Studio. Los artefactos Android se nombran R104.4 para evitar confusión con R104.3.

## Verificación

- Coincidencia de las dos copias de `KombaxTerminalManager.java`: comprobada por hash.
- La compilación Gradle desde este ejecutor sigue bloqueada antes de compilar código por `Unable to establish loopback connection`, una restricción local de comunicación entre procesos. La compilación Android Studio y la firma real quedan pendientes de una nueva ejecución por el propietario.
- No se ha generado ni afirmado una APK/AAB firmada.

Si Android Studio muestra otro error tras sincronizar o reconstruir, conservar el primer mensaje de `Build Output` y corregirlo sobre esta base.
