# KOMBAX 20178 · FIX09 acumulativo

Incluye FIX08. No se ha hecho push a GitHub, despliegue Netlify ni compilación/subida de APK o AAB.

## Eliminación Owner

- Social: «Eliminar», con sesión Owner válida, motivo y confirmación ELIMINAR, borra la publicación y sus relaciones dependientes. La multimedia exclusiva que no pertenece a un álbum queda en la cola de limpieza.
- Showcase: borra el producto cuando no tiene referencias restrictivas. Si hay pedidos, reseñas, movimientos de stock u otras referencias históricas, conserva la ficha necesaria, archivada y sin venta, descripción ni galería comercial. Conserva los registros de pedidos y seguridad.
- Los archivos propios de Social y Showcase se eliminan mediante Storage API. Se comprueban referencias antes de encolarlos y antes de procesarlos. No se borran archivos ajenos, externos, compartidos ni álbumes. Las rutas antiguas no identificables o de otras colecciones se conservan por seguridad.
- La limpieza del servidor se ejecuta cada minuto, con hasta 20 archivos por ejecución. Reintenta fallos; tras diez intentos deja el registro en estado failed para revisión. No se promete liberación instantánea de todo el almacenamiento.
- Se conserva el motivo, autor y registro de intervención; las copias de texto e imágenes de esa publicación/producto se quitan del historial de moderación.
- «Retirar» continúa ocultando contenido sin destruirlo. No se ha hecho ninguna eliminación masiva de contenido existente.
- Misma llamada de backend app_kombax_content_action_r118: compatible con clientes que ya la utilizan. Los errores de sesión y confirmación utilizan mensajes reconocibles por el frontend actual.

## Supabase activado y verificado

- Migración kombax_owner_social_hard_delete_r119: 20261004122656.
- Migración kombax_content_cleanup_cron_r119: 20261004122748.
- Función kombax-content-cleanup versión 1: autenticación mediante secreto de servidor, sin acceso desde cuentas normales.
- Primera ejecución programada: HTTP 200, claimed=0, completed=0, failed=0.
- Antes/después: 12 publicaciones Social y 5 productos Showcase. No se borró contenido real para probarlo.
- No reaplicar estas migraciones al proyecto actual. Una instalación nueva necesita configurar el secreto y el proceso cron autenticado; la migración cron comprueba que existe su plantilla.

## QA y límites

- Base PostgreSQL aislada: 55 comprobaciones, incluyendo permisos, confirmación, borrado de comentarios, productos con pedidos, conservación de álbumes y referencias compartidas, protección de archivos ajenos, reintentos y permisos de limpieza.
- Worker: prueba del uso de Storage API y del reintento tras error.
- Regresión acumulativa: 79 suites aprobadas, 3 P2 conocidos de traducción, 0 fallos nuevos. La suite estricta completa todavía tiene esas incidencias.
- Compatibilidad: 364 JavaScript, 855 imports Linux; web/dist/Android idénticos.
- No se ha probado el botón de borrado desde tu APK instalada ni se han eliminado archivos reales como prueba. El backend está activado; el funcionamiento completo en esa APK sigue pendiente de corroboración.
- El plan siguiente de perfiles públicos separados y suscripciones por organización está incluido como plan, no como implementación terminada.
- Las verificaciones y límites PDF de FIX08 siguen documentados en su LEEME.
- Este archivo fuente conserva versionCode 20178. Si Google Play ya lo ha utilizado, la próxima compilación debe asignar un código superior. No es una nueva APK/AAB firmada.

## Reunir y utilizar

Descarga las cuatro partes FIX09 y UNIR_KOMBAX_20178_FIX09.cmd en la misma carpeta. Ejecuta el CMD: reúne el ZIP y verifica su SHA-256. Extrae el proyecto, conserva tu carpeta .git y configuraciones privadas, revisa los cambios y realiza tu push. El ZIP excluye credenciales, firmas y node_modules. No mezcles partes FIX08 y FIX09.
