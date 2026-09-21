# SUPABASE RUNBOOK · KOMBAX RC13 build 20030

## Estado remoto confirmado al iniciar este runbook

- 037–050: aplicadas/verificadas.
- 051: aplicada; verify **9/9 TRUE**.
- 052: preflight **4/4 TRUE**; migración todavía **NO ejecutada**.
- 053–056: pendientes.
- 057: implementada en código 20030; pendiente de instalación.

Por tanto, **el siguiente paso real es ejecutar la migración 052**, no 051 ni 057.

## Reglas

- Backup antes de continuar.
- Confirmar el proyecto Supabase correcto.
- Una fase cada vez: `preflight → migration → verify → transactional test`.
- Detenerse ante cualquier `false`, `FAIL` o error.
- No desactivar RLS.
- No aplicar fixtures demo en producción.
- No usar rollback para probar; solo ante incidencia confirmada.
- 054 debe ser el incluido en este build (contiene Storage de Showcase).

## Secuencia pendiente exacta

| Fase | Estado | Preflight | Migración | Verify | Test |
|---|---|---|---|---|---|
| 051 Identidad/contexto | ✅ aplicada/verificada | `preflight_051_identity_context.sql` | `051_kombax_identity_context.sql` | `verify_051_identity_context.sql` | pendiente E2E JWT si no se ejecutó |
| 052 Perfil público | preflight 4/4 ✅ | `preflight_052_public_profiles.sql` | `052_kombax_public_profiles.sql` | `verify_052_public_profiles.sql` | `test_052_public_profiles_transactional.sql` |
| 053 Multimedia Social | pendiente | `preflight_053_social_media.sql` | `053_kombax_social_media_publisher.sql` | `verify_053_social_media.sql` | `test_053_social_media_transactional.sql` |
| 054 Showcase + Storage | pendiente | `preflight_054_showcase_actions.sql` | `054_kombax_showcase_actions.sql` | `verify_054_showcase_actions.sql` | `test_054_showcase_actions_transactional.sql` |
| 055 Platform admin | pendiente | `preflight_055_platform_admin.sql` | `055_kombax_platform_admin.sql` | `verify_055_platform_admin.sql` | `test_055_platform_admin_transactional.sql` |
| 056 Release contract | pendiente | `preflight_056_release_contract.sql` | `056_kombax_release_contract.sql` | `verify_056_release_contract.sql` | `test_056_release_contract_transactional.sql` |
| 057 Ámbitos/privacidad | pendiente | `preflight_057_work_scopes.sql` | `057_club_work_scopes_finance_privacy.sql` | `verify_057_work_scopes.sql` | `test_057_work_scopes_transactional.sql` |

## Gate 057

El preflight 057 exige que `app_kombax_release_contract_v056()` exista. No aplicar 057 antes de completar 056.

Verify 057 comprueba en una sola consulta, entre otras cosas:
- tablas de ámbitos;
- un único ámbito principal;
- helpers de alumnos/grupos;
- guards de asistencia/seguimiento;
- proyecciones seguras de alumnos/cartera/progreso;
- cobro controlado;
- `puede_ver_socio` sin acceso de monitor;
- fila `socios` privada;
- documentos/Storage privados;
- recibos privados;
- reservas/series limitadas;
- gateway de sesiones con `MONITOR_SCOPE_REQUIRED`.

## Test real 057

No certificar solo desde SQL Editor como `postgres`. Usar sesiones JWT reales:

1. Gestor/Coordinación crea Ámbito A y B.
2. Monitor A + Alumno/Grupo A.
3. Monitor B + Alumno/Grupo B.
4. Confirmar aislamiento cruzado.
5. Probar `none/status/portfolio/collect/receipts`.
6. Probar flags de asistencia/seguimiento en true/false.
7. Confirmar documentos/recibos administrativos cerrados al monitor.
8. Confirmar Gestor mantiene acceso global permitido.

## Rollback

Si fuera necesario tras 057: revertir primero 057 y luego, solo si corresponde a la incidencia, continuar 056 → 055 → 054 → 053 → 052. Documentar cualquier reversión.
