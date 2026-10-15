# Eliminación de álbum, Material y Showcase — R271

La revisión confirma controles existentes de eliminación/retirada en los tres espacios. No se han ampliado roles ni duplicado los formularios.

## Corrección añadida

Migración `20261014231510_social_album_shared_media_r271.sql`: retirar del álbum Social desmarca `en_album`, conserva el archivo y el estado del medio cuando una publicación lo referencia y no autoriza la limpieza de archivos compartidos con otros álbumes. Mantiene el endpoint anterior, su autorización e idempotencia. Helper privado sin acceso anon/authenticated.

Frontend: respeta `cleanup_allowed` para conservar también la portada de vídeo compartida. Para álbumes Club/directos, los endpoints antiguos no certifican ausencia de referencias: se elimina la entrada visible pero se conserva prudentemente el archivo original y su portada. Esto no equivale a liberar todo el almacenamiento. No se implementa un recolector de archivos huérfanos en esta entrega.

## Material y productos

Material ya ofrece Desactivar, Archivar y Eliminar sin histórico, según permisos. Backend rechaza eliminar si hay pedidos o entregas. Showcase ya elimina definitivamente una ficha sin historial, o la retira si hay pedidos, valoraciones, consultas, contactos, movimientos u otros registros protegidos. Conserva historial y mensajes. No se ha ejecutado eliminación de material o productos reales para probar.

## Verificación

15 comprobaciones aisladas PGlite: archivo exclusivo, publicación compartida, otras referencias Club/directo, separación de cuentas, sesión obligatoria, otros comandos preservados y helper privado. Prueba del endpoint desplegado v085 con contexto de propietario y transacción revertida: retiró del álbum sin romper publicación y sin permitir borrado de archivo. Ningún cambio de contenido de esa prueba se conservó.

No se ha probado la interacción final de eliminación con sesión real de navegador en esta ampliación. El frontend actualizado requiere la futura actualización manual; no se ha hecho despliegue en Netlify ni GitHub. La entrega ZIP se reanuda por petición posterior del usuario.

## Registro backend

Migración remota `social_album_shared_media_r271`, versión `20261014231852`. Consulta posterior al ROLLBACK: las tres entradas reales de álbum compartidas con publicaciones siguen intactas. Advisors de seguridad: sin hallazgo nominal para el helper nuevo; persisten avisos globales heredados de endpoints SECURITY DEFINER, RLS sin políticas y protección de contraseñas filtradas. No se declara el proyecto libre de avisos. `ROLLBACK_ALBUM_R271.sql` conserva la función previa; no se ha ejecutado.
