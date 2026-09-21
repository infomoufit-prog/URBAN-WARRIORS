# KOMBAX 20.110 R60 · Backend State — Pilot Final Profile / Chat / Network / Media

Proyecto Supabase activo: `poggsobhtutbuagjiydc`

## Edge Functions relevantes

- `kombax-assist-r38`: línea de Assist/Support/Migrations reconciliada en la fase anterior; Soporte guiado permanece separado de Management Assist.
- `kombax-history-delete-r60`: **ACTIVE v3**.
  - Valida sesión mediante Bearer contra Supabase Auth.
  - Acepta `migration`, `assist` y alias `management` → Assist.
  - No borra Soporte al borrar Assist/Migrations.
  - Elimina archivos staging cuando corresponda y finaliza el borrado transaccional.
  - Preserva los contadores/allowances ya consumidos.

## Migraciones incluidas en este cierre

- `253_kombax_pilot_management_assist_r60.sql`
- `254_kombax_support_guided_management_split_r60.sql`
- `255_kombax_pilot_profile_chat_network_media_fix_r60.sql`
- `256_kombax_relation_state_network_compat_r60.sql`
- `257_kombax_pilot_public_qa_cleanup_r60.sql`

## RPC / superficie final relevante

- `app_kombax_customer_history_delete_plan_r60`: autenticado; no anon.
- `app_kombax_relation_request_v255`: autenticado; no anon.
- `app_kombax_relation_state_v255`: autenticado; no anon.
- `app_kombax_social_network_profiles_v255`: autenticado; no anon.
- `app_kombax_social_profile_posts_v255`: autenticado; no anon.
- `app_kombax_social_network_actor_allowed_v255`: helper interno; no expuesto como RPC directa de cliente.

## Red Social

La capacidad de red se separa de la capacidad de publicación. Un miembro activo/verificado de club puede utilizar su actor Social válido para gestionar su red sin recibir permisos administrativos ni permiso de publicar por esa razón.

## Media en actividad de perfil

Se verificó en datos live la existencia de una publicación reciente con media `video` y path `.mp4`. La nueva proyección de publicaciones de perfil entrega media autorizado al frontend, que ahora lo renderiza en `Actividad KOMBAX`.

## Limpieza de QA público

Se ocultaron del directorio público (`visible=false`) las identidades ficticias detectadas:

- `FEDERACIÓN KOMBAX QA · DEMO`
- `NORA VEGA · COMPETIDORA QA`
- `QA-CLUB-001 · KOMBAX QA TEST`

No fueron eliminadas para conservar capacidad de QA interno.

## Nota de seguridad global

Los advisors globales de Supabase siguen mostrando backlog histórico de permisos/RLS y performance. Esta entrega no intenta reescribir de forma masiva cientos de contratos `SECURITY DEFINER`, policies o índices en la víspera del piloto. El hardening global debe cerrarse en un carril controlado y auditado por módulo antes de declarar producción general.
