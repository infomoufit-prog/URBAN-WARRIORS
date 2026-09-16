# Supabase · KOMBAX Eventos Workspace Audit 20.097

## Hallazgo
La cuenta gestora auditada de Urban Warriors también posee una identidad directa Federación QA verificada con `events.public.organize`. El RPC 160 era account-wide y podía devolver ambos contextos.

## Corrección
- `app_kombax_eventos_organizador_contexto_v171(uuid)` — solo Club del workspace.
- `app_kombax_evento_contexto_gestion_v171(uuid,uuid)` — gestión ligada al workspace.
- `app_kombax_eventos_mutate_v171(text,jsonb,uuid)` — transporta y valida `workspace_club_id`.
- `app_kombax_eventos_invitaciones_contexto_v172(uuid)` — invitaciones solo del Club activo.

## ACL comprobado
Las cuatro superficies contextuales no son ejecutables por `anon`. El gateway de mutación es ejecutable por `authenticated` y aplica controles internos.

## Estado comercial
No se ha añadido `events.public.organize` al plan `club_saas` ni a Club Básico. Urban Warriors se habilitará mediante override piloto explícito únicamente tras desplegar la frontend 20.097.
