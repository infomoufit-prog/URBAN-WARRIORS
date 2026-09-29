# R28 · Manifiesto de recuperación de migraciones históricas

Durante la auditoría pre-piloto R109 se confirmó un hueco de portabilidad en el ZIP acumulativo: el árbol local no contiene los archivos originales correspondientes a tres migraciones R28/v196, aunque el Supabase activo las registra como aplicadas y conserva sus sentencias históricas.

## Historial confirmado en Supabase

| Versión | Nombre | Tamaño de la sentencia histórica |
|---|---|---:|
| `20260830221459` | `kombax_profile_capability_foundation_20101_r28` | 17.109 caracteres |
| `20260830221550` | `kombax_profile_professional_spectator_mutations_20101_r28` | 17.508 caracteres |
| `20260830222259` | `kombax_profile_capability_advisor_hardening_20101_r28` | 1.190 caracteres |

También se verificó en vivo la existencia de los objetos v196 utilizados actualmente (`app_kombax_perfil_mutate_v196`, `app_kombax_profile_capabilities_v196`, `app_kombax_profile_taxonomy_v196` y tablas de perfiles/especialidades).

## Decisión R109

No se crean migraciones 196/197/198 nuevas ni se copian bajo `supabase/migrations`, porque el proyecto vivo ya las tiene aplicadas y un archivo con identidad distinta podría aparecer como pendiente y provocar una reaplicación incorrecta. Tampoco se reconstruye SQL por aproximación.

El historial de Supabase (`supabase_migrations.schema_migrations.statements`) es la fuente autorizada para recuperar el SQL exacto. Se incorpora `maintenance/recover-r28-migration-source.sql`, que realiza únicamente una lectura de esas tres filas.

**Estado:** PASS CON OBSERVACIÓN. El runtime vivo tiene la arquitectura R28; un restore completamente aislado desde el ZIP requiere primero recuperar/archivar las sentencias exactas del historial autorizado.
