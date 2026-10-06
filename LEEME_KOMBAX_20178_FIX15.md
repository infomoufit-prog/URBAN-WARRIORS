# KOMBAX FIX15 acumulativo · 6 de octubre de 2026

Contiene FIX14 completo y el ajuste de la imagen de los siete peleadores en el onboarding principal y en Inicio/exploración. La imagen original permanece intacta. Se muestra completa e integrada en el panel premium original, sin ampliación ni recortes y con espacio para el texto. No cambia formularios, permisos, cobros ni reglas del piloto.

Descarga las cuatro partes KOMBAX_20178_R120_FIX15.zip.001 a .004 y UNIR_KOMBAX_20178_FIX15.cmd en la misma carpeta. Ejecuta el CMD, que reunifica y comprueba SHA-256, y extrae el ZIP completo en una carpeta nueva. No mezcles partes de diferentes FIX.

Para actualizar GitHub, copia el contenido del proyecto a la raíz conservando .git, variables privadas y claves de firma. Revisa tus cambios pendientes antes de sustituir archivos. El nuevo ajuste requiere desplegar el frontend actualizado en Netlify. No se ha hecho push ni despliegue de producción.

No hay nuevas migraciones Supabase en FIX15: se conservan las tres ya aplicadas de FIX14 y todas las correcciones anteriores. No vuelvas a ejecutarlas si están registradas. Las finanzas piloto y las automatizaciones desactivadas se mantienen.

Los recursos web/dist/Android están sincronizados. No se incluye una APK/AAB nueva compilada; una nueva subida a Play necesita un versionCode no utilizado y conservar tu firma.

Informe vigente: docs/qa/AUDITORIA_ACUMULATIVA_FIX15.md. Las instrucciones y el alcance funcional de FIX14 siguen en LEEME_KOMBAX_20178_FIX14.md.
