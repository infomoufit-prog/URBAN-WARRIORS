# KOMBAX RC13 · build 20041

## Ciclo de vida del contenido
- KOMBAX Social: eliminación real de publicaciones propias; likes, comentarios y guardados dependientes desaparecen por cascada.
- Multimedia Social huérfana no perteneciente al álbum: marcada `removed` y preparada para limpieza del objeto Storage por el cliente propietario.
- Contacto KOMBAX: `Eliminar conversación` elimina la copia del participante y cierra el hilo, sin destruir la copia de la contraparte.
- Showcase: eliminación real de elementos propios/gestionables y limpieza de imágenes KOMBAX propiedad del usuario.
- Perfil público de miembro: eliminación explícita de foto pública y portada.
- Álbumes de club/perfil: terminología unificada a `Eliminar` cuando el backend ya retiraba también el objeto Storage.

## Multimedia adaptable
- Imágenes y vídeos de contenido respetan relación de aspecto mediante `object-fit: contain` y límites de altura/tamaño.
- Showcase público deja de expandir imágenes sin límite; usa una miniatura acotada.
- Showcase detalle, tienda, portada Social, portada del club y vídeo de álbum respetan vertical/horizontal/cuadrado.
- Avatar/logo siguen usando `cover` de forma intencional por tratarse de marcos de identidad.
- Miniaturas fotográficas de álbum pueden recortar en cuadrícula, pero la vista completa conserva la imagen íntegra.

## Backend
- Migración 067 aplicada y verificada en Supabase.
- Nuevos gateways v067 para Contacto KOMBAX, Social y Showcase.
- Tombstones por participante en `kombax_social_contactos`.
- Rollback 067 bloqueado por defecto para impedir que una reversión a RPC v065 reexponga conversaciones eliminadas.
