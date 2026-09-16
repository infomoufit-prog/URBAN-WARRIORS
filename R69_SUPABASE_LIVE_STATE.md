# KOMBAX R69 · Estado Supabase live

**Proyecto:** `poggsobhtutbuagjiydc`

## Migración R69 aplicada

- Versión: `20260914083811`
- Nombre: `kombax_r69_event_center_operations`

RPC añadida:

- `public.app_kombax_event_center_list_r69(p_limit integer)`

Permisos verificados:

- `anon`: sin EXECUTE.
- `authenticated`: EXECUTE permitido.
- Cada fila exige además permiso real mediante `app_kombax_evento_puede_gestionar_v160(event_id)`.

La RPC no introduce tablas ni escritura de datos; agrega información sobre eventos ya gestionables y reutiliza los ledgers de Ticketing/analytics existentes.

## Edge Function health

- `health`: ACTIVE
- versión live: **28**
- build: **20120**
- `verify_jwt=false` se mantiene intencionadamente porque este endpoint ya era público.

## Seguridad

R69 no declara el estado global de Advisors como limpio. Se mantiene la deuda histórica/global ya documentada: funciones `SECURITY DEFINER` heredadas y configuración Auth pendiente de hardening antes del lanzamiento público, incluida protección de contraseñas filtradas donde proceda.

La nueva RPC R69 sigue el patrón actual del proyecto pero añade controles explícitos de autenticación, autorización por evento, `search_path=''` y revocación a `anon/public`.
