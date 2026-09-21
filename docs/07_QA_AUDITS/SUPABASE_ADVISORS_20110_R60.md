# Supabase Advisors — KOMBAX 20.110 R60

Fecha de revisión: 07/09/2026.  
Proyecto revisado: entorno Supabase actual de KOMBAX.

## Conclusión

Los advisors **no están cerrados globalmente**. R60 puede continuar como candidata de estabilización, pero no debe declararse production-ready hasta revisar y cerrar los avisos que afecten al flujo final del piloto.

## Security Advisor

El advisor mantiene un backlog histórico amplio. Entre los avisos relevantes para revisar antes de producción aparecen:

- `function_search_path_mutable`, incluyendo funciones R60 como:
  - `app_kombax_migration_guide_access_r60` / acceso de guía equivalente;
  - `app_kombax_history_delete_plan_r60`;
  - `app_kombax_history_delete_finalize_r60`.
- políticas/avisos RLS históricos en otras áreas del proyecto;
- `extension_in_public` para extensiones históricas;
- protección de contraseñas filtradas (`auth_leaked_password_protection`) no habilitada a nivel de proyecto.

Estas observaciones deben revisarse de forma conservadora, sin aplicar un hardening masivo durante una estabilización sin QA de regresión.

Referencia Supabase Database Linter: https://supabase.com/docs/guides/database/database-linter

Referencia de seguridad de contraseñas: https://supabase.com/docs/guides/auth/password-security

## Performance Advisor

Existe deuda histórica de:

- claves foráneas sin índice de cobertura;
- índices todavía no utilizados;
- un aviso de índice duplicado histórico en `public.informes_financieros`.

Los índices R60 de auditoría/borrado aparecen todavía como no utilizados, algo esperable al ser nuevos y no haber recibido tráfico suficiente.

Referencia del linter para FKs sin índice: https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys

Referencia para índices duplicados: https://supabase.com/docs/guides/database/database-linter?lint=0009_duplicate_index

## Decisión de entrega

No se modifican de forma masiva estos avisos dentro del ZIP R60. El objetivo es evitar introducir regresiones fuera del alcance de Migrations/Guide/History. Se registran como gate de estabilización para una revisión específica antes de producción/piloto oficial.
