# Cybersecurity Handoff · R49

## Estado R49
Las funciones nuevas R49 son `SECURITY DEFINER` con `SET search_path=public,auth`, requieren `auth.uid()`, validan acceso Social y revocan EXECUTE a `anon`.

## Advisor Security
El advisor del proyecto sigue reportando deuda global heredada, entre ella:
- vistas Security Definer;
- políticas RLS excesivamente permisivas / `always true` en diversas tablas históricas;
- protección de contraseñas filtradas desactivada;
- versión de PostgreSQL con actualizaciones de seguridad disponibles.

R49 no declara el proyecto “cybersecurity approved”. El saneamiento global de Advisors debe realizarse como fase propia para evitar cambios de autorización fuera de alcance.

## Advisor Performance
Persisten avisos globales de:
- foreign keys sin índice de cobertura;
- numerosos índices no utilizados;
- al menos un índice duplicado en `informes_financieros`.
También existen avisos históricos en tablas Social/Events. R49 no elimina índices ni modifica políticas de rendimiento global.

Referencias Supabase:
- https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys
- https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index
- https://supabase.com/docs/guides/database/database-linter?lint=0009_duplicate_index
- https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- https://supabase.com/docs/guides/platform/upgrading

## Secretos
El paquete final debe excluir keystore/`keystore.properties`, `.git` y `node_modules`. `google-services.json` contiene configuración cliente Firebase/Google esperada; no debe confundirse con una service-role key o clave privada de servidor.
