# KOMBAX R73 · Rollback

R73 está diseñado como capa aditiva sobre R72.

## Frontend
Volver al ZIP R72 congelado restaura la UI build 20123 y los repositorios RPC R72.

## Supabase
Usar `supabase/rollbacks/20260914195741_kombax_r73_reputation_community_completion_rollback.sql` para retirar permisos de ejecución de los RPC R73.

El rollback **no elimina** `event_comments.kind`, `event_reactions`, reseñas, comentarios ni reputación. La preservación es intencionada para evitar pérdida de historial/auditoría. Los RPC R72 permanecen disponibles.

## Regla
No ejecutar borrado destructivo de reputación, productos históricos, pedidos o asistencia como parte de un rollback funcional.
