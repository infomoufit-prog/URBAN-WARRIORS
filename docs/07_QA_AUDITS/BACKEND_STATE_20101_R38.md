# KOMBAX 20.101 R38 · Backend State

## Supabase live
Proyecto: `poggsobhtutbuagjiydc`.

Migraciones R38 live verificadas:
- `20260904085455` · `kombax_assist_economy_foundation_r38`
- `20260904085532` · `kombax_assist_customer_api_r38`
- `20260904085608` · `kombax_assist_service_api_r38`
- `20260904085644` · `kombax_migration_metering_r38`
- `20260904085708` · `kombax_assist_privacy_economy_hardening_r38`
- `20260904092154` · `kombax_assist_migrations_channel_split_r38`
- `20260904092614` · `kombax_customer_ops_activation_gate_r38`
- `20260904092910` · `kombax_assist_r38_fk_performance_indexes`

## Contrato visible
- Assist estándar: email-first; el chat requiere una `guided_session` activa y no expirada.
- Migrations: ticket `MIGRATION` con acceso directo a chat + staging documental, sin activación previa de Assist.
- Ambos flujos comparten ledger y guardrails económicos internos, pero no comparten el procedimiento de entrada.

## RPCs de cierre
### `app_kombax_assist_turn_reserve_v227(text,text,text)`
- `authenticated`: EXECUTE.
- `anon`: sin EXECUTE.
- `service_role`: sin EXECUTE.
- Para tickets distintos de `MIGRATION`, devuelve `ASSIST_CHAT_NOT_ACTIVATED` si no hay sesión guiada activa.
- Para `MIGRATION`, conserva el flujo directo sujeto a cupo/guardrails.

### `app_kombax_customer_ops_mutate_v233(text,jsonb)`
- Customer-safe: `ticket.create` y `ticket.human_review`.
- `ticket.guided_start` se bloquea con `SUPPORT_CHAT_ACTIVATION_REQUIRED`.
- La mutación histórica `app_kombax_customer_ops_mutate_v213(text,jsonb)` ya no concede EXECUTE a `authenticated`.

## Edge Function
- Función live: `kombax-assist-r38`.
- Estado verificado durante este cierre: ACTIVE, versión 2.
- SHA verificado: `7afcd0db2672edfe9f3809a3ca638ee201b861e72c48d0cd7dae961a804a5fd3`.
- Autenticación Bearer validada dentro de la función.
- `store:false` en Responses API.
- Entradas multimodales para imágenes/archivos.
- El prompt de Migrations exige salida conservadora y prohíbe importación automática.

## Datos live al cierre
- `kombax_ai_ops.assistance_turns`: 0 filas.
- `kombax_customer_ops.assist_chat_messages`: 0 filas.
- `kombax_customer_ops.migration_file_analysis`: 0 filas.

## Advisors
- Rendimiento: los cinco avisos de FK sin índice introducidos por las tablas R38 fueron corregidos por 234. Los nuevos índices pueden aparecer como `unused_index` mientras todavía no exista tráfico, lo cual es esperable.
- Permanecen avisos históricos de rendimiento en otras tablas/esquemas; no se amplió R38 para reindexar todo el proyecto.
- Seguridad: el advisor sigue mostrando hallazgos históricos del proyecto (funciones antiguas, políticas y configuración global). R38 no se certifica como “advisor global limpio”; sus RPC de cierre usan `security definer` con `search_path` fijado y ACL restringida según lo auditado.
