# Android · KOMBAX 20.110 R60

## Identidad de actualización

- `applicationId`: `com.urbanwarriors.app`
- `versionCode`: `20110`
- `versionName`: `2.0.0-rc.13-r60-migrations-guide-history`
- `minSdk`: 24
- `targetSdk` / `compileSdk`: 36
- Java: 17

R60 debe firmarse con la **misma clave/cadena de firma ya utilizada por KOMBAX en Google Play**. Este ZIP no contiene JKS, contraseñas ni `android/keystore.properties`.

**No crear una clave nueva** para sustituir la firma existente.

## Firma local

Hay dos métodos soportados:

1. Copiar `android/keystore.properties.example` como `android/keystore.properties` y completar localmente la ruta/credenciales del JKS existente.
2. Usar variables de entorno:
   - `UW_KEYSTORE_PATH`
   - `UW_KEYSTORE_PASSWORD`
   - `UW_KEY_ALIAS`
   - `UW_KEY_PASSWORD`

Antes de una release:

```bash
npm run android:preflight
```

Debe quedar **5/5**. En el entorno de empaquetado R60 quedó 4/5 únicamente porque la firma real no se incorpora al ZIP.

## APK de QA

```bash
npm run android:debug:qa
```

Cuando Gradle pueda ejecutarse, el script genera y copia:

`artifacts/KOMBAX_20110_R60_MIGRATIONS_GUIDE_HISTORY_QA_DEBUG.apk`

## AAB para Google Play

Con la firma existente correctamente configurada:

```bash
npm run android:aab:play
```

El script genera y copia:

`artifacts/KOMBAX_20110_R60_MIGRATIONS_GUIDE_HISTORY_QA_GOOGLE_PLAY.aab`

Subir primero a **Google Play · Prueba interna**, instalar desde Play y realizar smoke test autenticado antes de cualquier promoción de pista.

## Estado de certificación de este ZIP

- Paridad `web = dist = Android`: **191 archivos**.
- Android preflight: **4/5**, pendiente únicamente la firma local.
- Intento Gradle del entorno de empaquetado: bloqueado por falta de acceso a `services.gradle.org`; por tanto este ZIP **no afirma que exista un APK/AAB R60 compilado**.
- Firebase Android está presente en el proyecto.

Los logs exactos están en `R60_FINAL_EVIDENCE/`.
