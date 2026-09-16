# SUPABASE ADVISORS · KOMBAX 20.101 R48

R48 no introduce DDL. Los Advisors se ejecutaron sobre el proyecto principal para conocer el estado global heredado.

## Security · NO CLEAN
Avisos observados:
- `function_search_path_mutable` en funciones existentes;
- leaked password protection desactivada;
- versión administrada de PostgreSQL con actualización de seguridad disponible.

Referencias oficiales:
- https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable
- https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- https://supabase.com/docs/guides/platform/upgrading

## Performance · NO CLEAN
Categorías observadas en el esquema existente:
- `auth_rls_initplan`;
- `unused_index`;
- `multiple_permissive_policies`;
- `unindexed_foreign_keys`;
- `duplicate_index`, incluyendo índices previos en `kombax_evento_media`.

Referencias oficiales:
- https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan
- https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index
- https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies
- https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys
- https://supabase.com/docs/guides/database/database-linter?lint=0009_duplicate_index

## Interpretación
No se atribuyen estos avisos a R48 porque R48 no modifica el backend. Deben tratarse como deuda global heredada y mantenerse como gate separado antes de declarar la plataforma completamente endurecida para producción.
