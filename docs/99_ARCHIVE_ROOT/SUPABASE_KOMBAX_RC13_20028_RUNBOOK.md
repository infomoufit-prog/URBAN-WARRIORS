# SUPABASE RUNBOOK · KOMBAX RC13 build 20028

## Estado de partida

El proyecto remoto debe tener 037–050 aplicadas/verificadas. El build 20028 añade 051–056. No reejecutar 037–050 para instalar 20028.

## Reglas

- Backup antes de comenzar.
- Confirmar que se está en el proyecto Supabase correcto.
- Ejecutar **una fase cada vez**.
- Orden obligatorio: `preflight → migration → verify → transactional test`.
- Parar ante el primer `false`, `FAIL` o error.
- No desactivar RLS.
- No usar fixtures demo en producción.
- No usar rollback para “probar”; solo ante incidencia confirmada y en orden inverso.
- Conservar salida de cada paso.

## Orden exacto

| Fase | Preflight | Migración | Verify | Test transaccional |
|---|---|---|---|---|
| 051 Identidad/contexto | `preflight_051_identity_context.sql` | `051_kombax_identity_context.sql` | `verify_051_identity_context.sql` | `test_051_identity_context_transactional.sql` |
| 052 Perfil público | `preflight_052_public_profiles.sql` | `052_kombax_public_profiles.sql` | `verify_052_public_profiles.sql` | `test_052_public_profiles_transactional.sql` |
| 053 Multimedia Social | `preflight_053_social_media.sql` | `053_kombax_social_media_publisher.sql` | `verify_053_social_media.sql` | `test_053_social_media_transactional.sql` |
| 054 Showcase acciones | `preflight_054_showcase_actions.sql` | `054_kombax_showcase_actions.sql` | `verify_054_showcase_actions.sql` | `test_054_showcase_actions_transactional.sql` |
| 055 Platform admin | `preflight_055_platform_admin.sql` | `055_kombax_platform_admin.sql` | `verify_055_platform_admin.sql` | `test_055_platform_admin_transactional.sql` |
| 056 Release contract | `preflight_056_release_contract.sql` | `056_kombax_release_contract.sql` | `verify_056_release_contract.sql` | `test_056_release_contract_transactional.sql` |

Los archivos de preflight/verify/test están en `supabase/verification`, las migraciones en `supabase/migrations` y los rollbacks en `supabase/rollbacks`.

## Conceder la llave global

Solo **después de aplicar/verificar 055**.

Usar:

`supabase/setup/grant_platform_admin.sql.example`

Sustituir el UUID de ejemplo por el UUID real de la cuenta/perfil que será propietario global. No usar un email hardcodeado en frontend ni guardar el UUID real en Git.

Ejemplo de intención:

```sql
insert into public.kombax_platform_admins(perfil_id,nivel,activo,motivo)
values('<UUID_REAL>'::uuid,'owner',true,'Administrador propietario KOMBAX')
on conflict(perfil_id) do update
set nivel='owner',activo=true,actualizado_en=now();
```

## QA E2E obligatoria después de 056

Probar al menos:
1. Gestor Urban Warriors: `Actuar como Urban Warriors · Club`.
2. Coordinación autorizada: publicar/editar según permisos.
3. Miembro adulto: aparece como `Miembro`, no Competidor.
4. Miembro 14–17 con edad verificada: acceso Social según reglas y sin contacto adulto indebido.
5. Competidor KOMBAX verificado: identidad distinta de miembro/perfil deportivo.
6. Perfil público clicable: avatar/banner/álbum/posts/relaciones/Showcase.
7. Subida directa Social foto/vídeo <=15 s.
8. Showcase: información/contacto/web/ubicación/guardar/compartir; sin checkout.
9. `platform_admin`: consola global, Clubes, perfiles, verificaciones, moderación y auditoría.
10. Usuario sin platform_admin: no puede abrir consola ni endpoints globales.
11. Segundo Club QA: cero cruces de tenant.
12. Storage: lectura/escritura/borrado conforme a identidad y permisos.

## Rollback

Si fuera imprescindible revertir, hacerlo en orden:
`056 → 055 → 054 → 053 → 052 → 051`.

Los rollbacks están diseñados para retirar la capa 20028 sin reescribir el historial 037–050. Revisar el impacto de datos creados durante QA antes de aplicar cualquier rollback.
