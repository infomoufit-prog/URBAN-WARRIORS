# CYBERSECURITY HANDOFF · KOMBAX 20.101 R48

## Cambios de superficie
R48 no añade DDL, tablas, buckets, RLS, Edge Functions ni endpoints. Reutiliza el álbum oficial de Events y el mutador autenticado existentes.

## Verificación local
Secret scan sobre rutas activas de código/runtime: 910 archivos, 0 hallazgos para patrones de API keys OpenAI, private keys y asignaciones service-role. Este escaneo es preventivo y no sustituye una auditoría de ciberseguridad.

## Verificación Supabase viva
- `kombax_evento_media`: RLS activo.
- `anon`: sin SELECT directo sobre tabla de media.
- `authenticated`: sin SELECT/INSERT directo sobre la tabla de media.
- mutador Events v191: EXECUTE para authenticated, no para anon.
- Co-Main y límites R22 presentes.

## Advisors · estado NO limpio heredado
R48 no generó DDL, por lo que estos avisos no son introducidos por R48. Aun así impiden declarar un cierre global de seguridad/performance.

### Security
- funciones existentes con `search_path` mutable.
- protección de contraseñas filtradas desactivada.
- versión administrada de PostgreSQL con actualización de seguridad disponible.

Remediación:
- https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable
- https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- https://supabase.com/docs/guides/platform/upgrading

### Performance
Se mantienen avisos heredados de:
- `auth_rls_initplan`;
- índices no usados;
- políticas permisivas múltiples;
- algunas FK sin índice;
- índices duplicados, incluidos índices existentes de `kombax_evento_media`.

Remediación:
- https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan
- https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index
- https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies
- https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys
- https://supabase.com/docs/guides/database/database-linter?lint=0009_duplicate_index

## Estado
R48 no está certificada como `cybersecurity-approved`. El cambio presenta una superficie incremental baja, pero el gate global requiere resolver/aceptar formalmente la deuda heredada y ejecutar QA autenticado real.
