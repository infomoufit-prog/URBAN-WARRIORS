# SUPABASE RUNBOOK · KOMBAX RC13 build 20029

## Estado de partida

El remoto ya tiene 037–050 aplicadas/verificadas. El build 20029 utiliza las migraciones pendientes 051–056.

**Importante:** 054 ha sido ampliada en 20029 para permitir la subida/borrado seguro de imágenes de Showcase. Como 054 todavía no se ha aplicado al remoto, debe ejecutarse directamente la versión incluida en este paquete.

## Reglas
- Backup antes de comenzar.
- Confirmar proyecto Supabase correcto.
- Una fase cada vez.
- Orden: `preflight → migration → verify → transactional test`.
- Parar ante cualquier `false`, `FAIL` o error.
- No desactivar RLS.
- No ejecutar fixtures demo en producción.
- Rollback solo ante incidencia confirmada y en orden inverso.

## Orden exacto

| Fase | Preflight | Migración | Verify | Test |
|---|---|---|---|---|
| 051 Identidad/contexto | `preflight_051_identity_context.sql` | `051_kombax_identity_context.sql` | `verify_051_identity_context.sql` | `test_051_identity_context_transactional.sql` |
| 052 Perfil público | `preflight_052_public_profiles.sql` | `052_kombax_public_profiles.sql` | `verify_052_public_profiles.sql` | `test_052_public_profiles_transactional.sql` |
| 053 Multimedia Social | `preflight_053_social_media.sql` | `053_kombax_social_media_publisher.sql` | `verify_053_social_media.sql` | `test_053_social_media_transactional.sql` |
| 054 Showcase + Storage | `preflight_054_showcase_actions.sql` | `054_kombax_showcase_actions.sql` | `verify_054_showcase_actions.sql` | `test_054_showcase_actions_transactional.sql` |
| 055 Platform admin | `preflight_055_platform_admin.sql` | `055_kombax_platform_admin.sql` | `verify_055_platform_admin.sql` | `test_055_platform_admin_transactional.sql` |
| 056 Release contract | `preflight_056_release_contract.sql` | `056_kombax_release_contract.sql` | `verify_056_release_contract.sql` | `test_056_release_contract_transactional.sql` |

Archivos:
- migraciones: `supabase/migrations`
- preflight/verify/tests: `supabase/verification`
- rollbacks: `supabase/rollbacks`

## Control especial 054

El verify 054 debe devolver también `TRUE` para:
- `upload_policy_ok`
- `delete_policy_ok`

Estas políticas permiten subir/borrar objetos bajo `kombax-public-media/<user>/showcase/<marca_id>/...` solo cuando el usuario autenticado puede gestionar el espacio Showcase indicado.

## Llave global

Solo después de aplicar/verificar 055.
Usar `supabase/setup/grant_platform_admin.sql.example` y sustituir el UUID de ejemplo por el UUID real de la cuenta propietaria. No autorizar por email en frontend.

## QA después de 056
1. Gestor: actuar como Club.
2. Coordinación autorizada: actuar como Club.
3. Miembro adulto: Social como Miembro, no Competidor automático.
4. Publicar texto directamente desde el feed.
5. Publicar foto/vídeo <=15 s.
6. Scroll progresivo del feed sin duplicados.
7. Abrir perfil público desde autores/tarjetas.
8. Comunidad del Club permanece interna.
9. Showcase: crear borrador, subir imágenes, publicar y ver públicamente.
10. CTA Showcase: información/contacto/web/ubicación/guardar/compartir.
11. Segundo club QA: aislamiento completo.
12. platform_admin: consola global y auditoría.

## Rollback
Si fuera necesario: `056 → 055 → 054 → 053 → 052 → 051`.
El rollback 054 del build 20029 también retira las políticas Storage de Showcase.
