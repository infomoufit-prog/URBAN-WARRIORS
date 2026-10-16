# KOMBAX R278 acumulativo

Base R277 conservada, con guía maestra ampliada y reparación de Owner. Lee `docs/ENTREGA_FINAL_R278.md` y `docs/VALIDACION_R278.md` antes de actualizar.

No se ha actualizado GitHub ni Netlify. El backend R278 ya está aplicado en Supabase y no necesita volver a ejecutar la migración desde este paquete. No cambies secrets ni claves existentes.

1. Conserva copia de tu repositorio y configuración local.
2. Reunifica las cuatro partes, comprueba el SHA-256 y extrae el ZIP completo.
3. Actualiza el código del repositorio manteniendo su carpeta `.git` y los secrets fuera del código.
4. El comando de compilación sigue siendo `npm run release:build`, con publicación de `dist`.
5. Prueba el acceso de tu club piloto, la ayuda y Owner después de tu despliegue manual.

La puerta Owner exige iniciar sesión de nuevo. No se ha generado todavía el nuevo PDF real de marketing con una sesión administrativa válida; sí se han probado y revisado los siete formatos con datos aislados.

No se incluye una APK/AAB nueva compilada. Android contiene los recursos web sincronizados. Para Google Play se necesitará compilar y firmar con un código de versión no usado.
