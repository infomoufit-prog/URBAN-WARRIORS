# CHANGELOG 20101 R46 · SOCIAL FEED RELEVANCE

- Feed Social móvil pasa a patrón continuo: autor compacto, multimedia protagonista, resumen de interacción y tres acciones principales.
- La reacción primaria se presenta como «Me interesa» conservando la tabla/contador histórico de likes para compatibilidad.
- Acciones secundarias pasan a menú por publicación: Guardar, Contactar, Ocultar, Denunciar, Bloquear, Ajustar imagen o Eliminar según permisos.
- Nuevo ocultado personal persistente: no modera ni altera la publicación global.
- Nuevo feed `app_kombax_social_feed_v236` con scoring explicable: recencia + intereses + comentarios + guardados + afinidad histórica con autor.
- Los posts ocultados por el usuario se excluyen del feed.
- Paginación usa score + fecha + id. Runtime mantiene fallback a v085 si el backend no está actualizado.
- Mobile: feed edge-to-edge y multimedia con mayor altura útil; desktop/tablet preservados.
