# KOMBAX RC13 build 20.096 · Signing Transfer Certification

## Estado
Esta es una **edicion de traslado** de la build 20.096. No es una build funcional nueva y no cambia `versionCode` ni `versionName`.

## Integridad del producto
- El contenido funcional original de 20.096 se conserva byte a byte.
- Unica modificacion sobre un archivo original: `.gitignore`, ampliado para impedir que el JKS de traslado se incorpore accidentalmente a Git.
- Se anade `LOCAL_RELEASE_SIGNING/` y esta certificacion.

## Clave incluida por solicitud expresa del usuario
- Archivo empaquetado: `LOCAL_RELEASE_SIGNING/kombax-release.jks`
- SHA-256: `7c70adc0d8e7b9426990d86a3f4743e2794e391f725dd708082e48264183a415`
- No se incluyen passwords.
- No se ha generado ni reemplazado la clave original.

## Uso
Ejecutar `LOCAL_RELEASE_SIGNING/RESTORE_SIGNING_WINDOWS.cmd` en el ordenador nuevo y completar localmente las credenciales.

## Seguridad
Este ZIP pasa a contener material criptografico sensible. Debe guardarse como copia privada y no publicarse, compartirse con terceros ni subirse como artefacto publico.
