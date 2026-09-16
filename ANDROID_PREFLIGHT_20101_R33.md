# KOMBAX 20.101 R33 · Android preflight

Resultado automatizado: 4/5.

PASS:
- applicationId `com.urbanwarriors.app`
- versionCode `20101`
- assets/www presente
- Firebase presente

PENDIENTE:
- firma local (`android/keystore.properties`), deliberadamente excluida del ZIP.

Intento `assembleDebug`: no llegó a compilar porque Gradle Wrapper no pudo resolver `services.gradle.org` al intentar descargar Gradle 8.11.1 (`UnknownHostException`). No se clasifica como error de código Android.

Para release local, usar la clave de firma/upload key ya existente y no crear una nueva si se desea continuidad de actualización.
