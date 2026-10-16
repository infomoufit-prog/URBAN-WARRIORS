# Actualización R275

Descarga los cuatro fragmentos .001, .002, .003 y .004 y UNIR_KOMBAX_R275_ACUMULATIVO.cmd en una misma carpeta. Ejecuta el CMD: crea KOMBAX_R275_AYUDA_NATURAL_ACUMULATIVO.zip y comprueba SHA-256 automáticamente. Los fragmentos no se extraen por separado.

Extrae el ZIP final en una carpeta nueva y revisa docs/ENTREGA_FINAL_R275.md. Es un proyecto completo acumulativo; conserva tu copia anterior y los secrets fuera del repositorio. Para GitHub, usa la raíz que contiene package.json y netlify.toml. El comando de compilación sigue siendo npm run release:build y la carpeta publicada dist.

El backend de ayuda R275 ya está desplegado en Supabase. No hay migración nueva ni secrets nuevos. No ejecutes automáticamente todas las migraciones históricas. La migración R274 tiene una diferencia documentada de prefijo local/remoto; ya está aplicada.

Para recibir el flujo nuevo de conversación, actualiza manualmente el frontend. No se ha hecho deploy en GitHub ni Netlify. Gate: 125 comandos correctos, 3 P2 de traducción conocidos y cero fallos nuevos. Las pruebas de conversación usan proveedor simulado; falta una consulta real tras el despliegue del frontend.

No se incluye APK/AAB compilada. Los recursos Android están sincronizados.
