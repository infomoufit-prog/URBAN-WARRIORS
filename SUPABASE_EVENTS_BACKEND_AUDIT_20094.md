# Auditoría Supabase · KOMBAX Eventos · 20.094

Proyecto productivo verificado: `poggsobhtutbuagjiydc`.

## Migraciones aplicadas
- 20260827015155 · `kombax_events_live_results_20094`
- 20260827015236 · `kombax_events_media_highlights_20094`
- 20260827015302 · `kombax_events_history_hardening_20094`
- 20260827015338 · `kombax_events_media_function_marker_20094`
- 20260827015623 · `kombax_events_result_write_path_hardening_20094`
- 20260827020128 · `kombax_events_fk_indexes_20094`
- 20260827020228 · `kombax_events_media_asset_acl_20094`

## Seguridad comprobada
- Tablas públicas de Eventos continúan RPC-only: sin SELECT/DML directo para `anon` o `authenticated`.
- Gateway de mutación v166: `anon=false`, `authenticated=true`, además de guards de gestión.
- Bucket `kombax-events-media`: privado.
- `app_kombax_evento_media_asset_v165`: `anon=false`, `authenticated=false`, `service_role=true`.
- Media visible se expone mediante URL firmada temporal, no haciendo público el bucket.
- No se consulta ni migra `eventos_competicion`, `evento_participantes` o `evento_combates` de Mi Club.

## Rendimiento
El Performance Advisor detectó dos FK nuevos sin índice durante la implementación. Se añadieron:
- `idx_kombax_evento_combates_resultado_actualizado_por_v169`
- `idx_kombax_evento_media_creado_por_v169`
Tras repetir el advisor, ambos desaparecieron de `unindexed_foreign_keys`. Los avisos restantes pertenecen al baseline histórico o a índices nuevos aún sin tráfico.

## Edge Functions
- `health` v14 ACTIVE · build 20094 · `verify_jwt=false` por ser endpoint público de salud.
- `event-media-url` v1 ACTIVE · `verify_jwt=false` por servir landing pública; valida el asset server-side y solo firma media pública visible/no expirada.
