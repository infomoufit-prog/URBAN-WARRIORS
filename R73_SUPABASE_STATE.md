# KOMBAX R73 · Estado Supabase verificado

Proyecto auditado: KOMBAX principal, región EU West.  
Estado: **ACTIVE_HEALTHY** durante la auditoría.

## R72 preservado
Las 11 migraciones canónicas R72 siguen registradas y no han sido sustituidas:
- catalog foundation
- reputation schema
- showcase capacity
- catalog entitlements
- verified reputation helpers
- showcase reviews
- events community
- safe delete/storage
- reputation moderation
- contracts/policies
- reputation FK indexes

## R73 live
Migración registrada: `20260914195741 · kombax_r73_reputation_community_completion`.

Cambios mínimos:
- `event_comments.kind`: `comment | question`.
- `event_reactions`: una reacción por `(event_id,user_id)`; valores `like | fire | applause | support`.
- RLS activo; sin acceso directo anon/auth a la tabla; escritura/lectura pública controlada por RPC SECURITY DEFINER con `search_path=''`.
- Índices R73 para comentarios por tipo y reacciones por evento/usuario.

RPC R73 verificados:
- `app_kombax_showcase_reviews_r73`
- `app_kombax_showcase_seller_reviews_r73`
- `app_kombax_event_community_r73`
- `app_kombax_event_community_manage_r73`
- `app_kombax_event_comment_upsert_r73`
- `app_kombax_event_reaction_set_r73`

## Contratos de reputación
- Compra verificada: se vuelve a comprobar con `verified_purchase_order_r72(...)` al leer.
- Asistencia verificada: se vuelve a comprobar con `has_verified_attendance_r72(...)` al leer.
- El vendedor/organizador puede responder y reportar, no borrar libremente críticas legítimas de terceros.

## Health
Edge Function `health`: **ACTIVE v31**, build reportado **20124**. El código del ZIP coincide en build/headers.

## No ejecutado
- Sin deploy de frontend/Netlify.
- Sin push GitHub.
- Sin publicación Google Play.
- Sin activación de SaaS Billing.

## Smoke remoto
- `app_kombax_event_community_r73`: PASS sobre un evento público real.
- `app_kombax_showcase_reviews_r73`: PASS sobre un producto publicado real.
