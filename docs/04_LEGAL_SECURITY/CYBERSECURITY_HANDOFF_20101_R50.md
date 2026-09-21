# CYBERSECURITY HANDOFF · KOMBAX 20.101 R50

## Específico R50
- Guard HD Social: `search_path=public` verificado en vivo.
- EXECUTE directo del guard para `anon`: false.
- EXECUTE directo del guard para `authenticated`: false.
- Validación 1080p independiente de orientación.
- No se añadieron secretos al runtime.

## Estado global
R50 NO se declara `cybersecurity-approved`. El proyecto conserva deuda global de Advisors heredada. Performance Advisor mantiene, entre otros, FK sin índice, índices sin uso y el índice duplicado de `public.informes_financieros`.

Referencias Supabase:
- https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys
- https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index
- https://supabase.com/docs/guides/database/database-linter?lint=0009_duplicate_index

La fase de hardening global debe tratarse por separado; no se mezcló con el cambio multimedia R50.
