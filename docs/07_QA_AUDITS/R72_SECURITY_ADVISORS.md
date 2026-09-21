# KOMBAX R72 · Supabase Advisors

Auditoría ejecutada después de aplicar y verificar las once migraciones R72 live.

## Security Advisor
El proyecto no queda libre de deuda histórica:

- `rls_enabled_no_policy`: **167 INFO**. Incluye las cuatro tablas nuevas del esquema privado `kombax_reputation`. Estas tablas tienen RLS habilitado, el esquema/tablas están revocados a `anon/authenticated`, y el acceso funcional se realiza mediante RPC controladas. Aun así, el Advisor las contabiliza por no tener policies RLS directas.
- `anon_security_definer_function_executable`: **48 WARN**. Incluye dos lecturas públicas R72 deliberadas (`app_kombax_showcase_reviews_r72` y `app_kombax_event_community_r72`) y deuda histórica de RPC públicas. Debe revisarse globalmente antes del lanzamiento público.
- `authenticated_security_definer_function_executable`: **502 WARN**. Es una deuda arquitectónica amplia de RPC históricas y algunas R72; requiere revisión específica de superficie y privilegios antes de declarar producción pública.
- `auth_leaked_password_protection`: **1 WARN**. La protección contra contraseñas filtradas sigue desactivada.

Referencias de remediación Supabase:
- RLS sin policy: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
- `SECURITY DEFINER` accesible a anon: https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable
- `SECURITY DEFINER` accesible a authenticated: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- Protección de contraseñas filtradas: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Performance Advisor
Resultado posterior a R72:

- `unindexed_foreign_keys`: **215 INFO** globales; deuda mayoritariamente histórica.
- `unused_index`: **279 INFO**. Incluye índices R72 recién creados que todavía no han recibido tráfico; no se eliminan basándose solo en esta señal.
- `duplicate_index`: **1 WARN** histórico en `public.informes_financieros` (`idx_informes_financieros_club_fecha_v145` / `informes_club_generado_v155_idx`).

Verificación focal R72 contra `pg_constraint/pg_index`: el esquema `kombax_reputation` tiene **12 FKs y 0 sin índice de cobertura**.

Referencia de rendimiento:
- FKs sin índice: https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys
- Índices sin uso: https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index
- Índice duplicado: https://supabase.com/docs/guides/database/database-linter?lint=0009_duplicate_index

## Decisión de freeze
Los avisos anteriores se documentan como deuda de estabilización y **no bloquean el piloto controlado R72**, pero impiden etiquetar el sistema como producción pública final hasta completar la revisión global de privilegios, habilitar leaked-password protection y resolver los riesgos que se consideren materiales.
