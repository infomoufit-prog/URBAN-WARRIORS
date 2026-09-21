# Supabase Backend Audit · KOMBAX Eventos · build 20.093

## Estado live
Aplicadas en el proyecto Supabase principal:
- `20260827011546 · kombax_events_foundation_20090`
- `20260827011809 · kombax_events_organizations_20091`
- `20260827011917 · kombax_events_fighters_fight_cards_20092`
- `20260827013157 · kombax_events_social_viral_20093`
- `20260827013551 · kombax_events_fk_indexes_20093`

## Separación de dominios
`public.eventos_competicion` (Mi Club) permanece independiente. Las tablas `kombax_event*` no migran ni reflejan automáticamente eventos internos, alumnos privados ni combates internos.

## Tablas KOMBAX Eventos verificadas
- `kombax_eventos_publicos`
- `kombax_evento_entidades`
- `kombax_evento_participantes_publicos`
- `kombax_evento_combates_publicos`
- `kombax_evento_interes`
- `kombax_evento_social_links`

En las seis tablas:
- RLS: ON.
- anon: sin SELECT/INSERT/UPDATE/DELETE directo.
- authenticated: sin SELECT/INSERT/UPDATE/DELETE directo.
- acceso de producto mediante RPC explícitas.

## RPC / ACL focalizada
Lecturas públicas intencionales como landing, participantes/combates visibles y engagement agregado permiten `anon` y `authenticated`.

Mutadores `app_kombax_eventos_mutate_v160/v161/v162`:
- anon EXECUTE: NO.
- authenticated EXECUTE: SÍ.
- SECURITY DEFINER con `search_path=public, auth` fijo y comprobaciones de `auth.uid()`, identidad, entitlement e idempotencia.

`app_kombax_eventos_social_links_v162`:
- anon EXECUTE: NO.
- authenticated EXECUTE: SÍ.

## Advisors
### Performance
El primer pase detectó FKs sin índice únicamente en las nuevas tablas de Eventos. Se aplicó la migración 163 con 12 índices; el segundo pase ya no reporta esas FKs como no indexadas. Los avisos de índices todavía no utilizados son esperables en tablas recién creadas y vacías.

### Security
El advisor muestra `RLS enabled no policy` en tablas Events. Es intencional: son tablas RPC-only y los roles cliente no tienen privilegios DML directos.

También marca las RPC SECURITY DEFINER de lectura anónima. Las RPC públicas de Eventos son endpoints públicos deliberados y filtran visibilidad/estado/aceptación. Las RPC mutadoras no están concedidas a anon.

Existe un baseline histórico amplio de avisos de seguridad en funciones anteriores de KOMBAX. No se modificó globalmente durante Fase 4 para evitar una intervención transversal destructiva; deberá tratarse mediante auditoría específica independiente.

## Edge Function health
- Estado: ACTIVE.
- Version: 13.
- `verify_jwt=false` conservado por ser endpoint público de salud.
- Build anunciado: 20093.

## Límite de evidencia
El entorno de contenedor no resolvió DNS externo para un `curl` HTTP contra Supabase. No se declara esa prueba HTTP como realizada. La evidencia backend de esta fase proviene de ejecución directa en Supabase: migraciones, catálogo Postgres, ACL, RLS, RPC, advisors y Edge Function.
