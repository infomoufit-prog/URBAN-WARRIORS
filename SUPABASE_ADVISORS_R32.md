# Supabase Advisors · R32

## Evaluación
Los advisors se ejecutaron después del hardening R31/R32.

### Hallazgo nuevo corregido
Performance Advisor detectó dos policies SELECT permisivas simultáneas en `notificaciones` tras añadir el subject Profesional. Se corrigió mediante la migración 204, fusionando el branch `direct_profile` dentro de la policy histórica. El warning desapareció.
Remediación de referencia: https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies

### Performance remanente
- INFO históricos/nuevos de foreign keys sin índice de cobertura y de índices todavía no usados. En objetos recién creados no se fuerzan índices de auditoría sin ruta de consulta demostrada.
- WARN histórico de índice duplicado en `informes_financieros` (Finanzas Club), anterior a R28-R32; no se modifica en esta línea para evitar un cambio lateral no requerido.
Referencias:
- https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys
- https://supabase.com/docs/guides/database/database-linter?lint=0009_duplicate_index

### Security Advisor
El proyecto conserva deuda histórica extensa de funciones SECURITY DEFINER y tablas privadas RLS sin policies directas. R28-R31 usan deliberadamente RPC SECURITY DEFINER como API cerrada sobre tablas sin DML directo.

Auditoría dirigida R28-R31:
- `anon_execute=false` para todos los RPC sensibles auditados.
- RPC públicos solo `authenticated`.
- `search_path` explícito (`public` o `public, auth`).
- validación de `auth.uid()`, sujeto gestionado y capability en gateways sensibles.
- RLS activa en las 15 tablas privadas nuevas auditadas.
- cero DML directo `anon/authenticated` en dichas tablas.

Por tanto los WARN genéricos `authenticated_security_definer_function_executable` de los RPC públicos R28-R31 se clasifican como exposición controlada e intencional, no como bypass descubierto.
Referencias:
- https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable
- https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy

### Auth global heredado
El advisor también indica protección de contraseñas filtradas deshabilitada. Es un ajuste global de Auth no introducido por R28-R32.
Referencia: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
