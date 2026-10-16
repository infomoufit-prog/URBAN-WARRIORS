# KOMBAX R279 · Acumulativo completo

Incluye R278 y el ajuste visual posterior: asset principal de todos los peleadores como fondo predeterminado de los espacios administrativos. Se conservan los banners personalizados. No modifica los perfiles públicos reales ni añade las identidades ficticias utilizadas para las vistas previas locales.

1. Descarga las cuatro partes ZIP y `REUNIFICAR_R279_DESCARGAS.cmd` en una misma carpeta.
2. Ejecuta el reunificador. Extrae los fragmentos, une el ZIP y comprueba el SHA-256. No mezcles partes R278 con R279.
3. El resultado es `KOMBAX_R279_ESPACIOS_Y_AYUDA_ACUMULATIVO.zip`.
4. Guarda una copia del repositorio antes de sustituir su contenido. Conserva `.git` y tus claves fuera del paquete.
5. Actualiza manualmente GitHub. El comando de Netlify sigue siendo `npm run release:build`; la carpeta publicada es `dist`.

No se ha hecho commit, push, merge, PR ni despliegue Netlify. La migración y funciones Owner/ayuda de R278 ya están aplicadas en Supabase; no se han vuelto a desplegar por este ajuste visual. No cambies los secrets existentes.

La compilación web y los recursos Android están sincronizados. No se incluye una APK/AAB nueva compilada ni firmada. Google Play requiere un código de versión no utilizado si vuelves a compilar.

Consulta `docs/ENTREGA_FINAL_R279.md` para el alcance y los límites de las pruebas.
