# KOMBAX FIX19 acumulativo

Coloca las cuatro partes .zip.001 a .zip.004 y UNIR_KOMBAX_20178_FIX19.cmd en una misma carpeta. Ejecuta el CMD para reconstruir el ZIP y comprobar SHA-256. Extrae el ZIP completo, no cada fragmento.

Incluye FIX18 y las correcciones de acceso gratuito, invitación voluntaria al perfil público, validación de publicación y solicitud puntual de eventos. Una cuenta sin perfil puede explorar Social, Showcase y Events y comprar; el perfil Espectador permite interactuar, pero no publicar. Los demás perfiles necesitan su validación y Miembro su vínculo aprobado a un club. Los clubes piloto autorizados conservan su acceso.

Supabase ya contiene las tres migraciones FIX19 en el proyecto poggsobhtutbuagjiydc. No hay que reaplicarlas manualmente al mismo proyecto. Para mostrar los cambios visuales debes actualizar el frontend en Netlify. No se ha desplegado producción ni publicado en Google Play.

Conserva .git, las variables privadas y la firma Android original. Revisa los cambios antes del push; este ZIP no contiene credenciales locales ni claves de firma. Se incluyen los recursos Android sincronizados, sin APK/AAB compilada. Una nueva AAB requiere un versionCode no usado; 20178 ya está usado.

Pruebas, resultados y límites: docs/qa/AUDITORIA_REGLAS_ACCESO_FIX19.md. No se realizaron compras ni cobros reales. No se promete ausencia de errores en todos los flujos no probados.
