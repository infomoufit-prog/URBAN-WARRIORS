# KOMBAX 20.101 R19 · Android / Google Play Release Checklist

## Antes de generar APK/AAB
- `npm run build` debe pasar.
- `npm run android:preflight` debe terminar 5/5.
- Restaurar `android/keystore.properties` localmente. No guardar contraseñas en Git/ZIP compartido.
- Confirmar package id: `com.urbanwarriors.app`.
- Confirmar firma con el JKS release existente.

## Versionado Google Play
La fuente R19 conserva `versionCode 20101`.
Si Google Play ya tiene un AAB/APK con versionCode 20101, Android/Google Play exigirá incrementar el versionCode antes de una nueva subida. No cambiarlo automáticamente sin confirmar qué versionCode está actualmente publicado/subido en la consola.

## APK Signed para validación
- Build > Generate Signed Bundle / APK > APK.
- Seleccionar el keystore release de KOMBAX.
- Instalar en dispositivo.
- Validar login, Social, Showcase, Events, Mi Club y específicamente los 3 productos R19.

## AAB para Play
- Build > Generate Signed Bundle / APK > Android App Bundle.
- Usar exactamente la misma identidad/firma release.
- Comprobar el artefacto antes de subir.
- Usar primero track interno/cerrado antes de producción cuando proceda.

## Estado de esta entrega
- Proyecto Android y JKS: incluidos.
- Assets R19 en Android: incluidos y verificados.
- Firebase: verificado.
- APK Signed: NO generada aquí.
- AAB Signed: NO generado aquí.
- Motivo: `android/keystore.properties` no se incluye con credenciales de firma.
