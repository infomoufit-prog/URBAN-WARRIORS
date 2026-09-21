# CHANGELOG · KOMBAX RC13 build 20028

## Added
- Sistema reutilizable de contexto de identidad y `Actuar como`.
- Identidad Social `Miembro` separada de Competidor KOMBAX.
- Permisos de equipo para actuar como Club y auditoría del actor real.
- Hub KOMBAX del Club para Gestor/Coordinación.
- Perfil público completo y navegable desde Social.
- Editor público de bio/avatar/portada para identidad Social de miembro.
- Subida directa de foto/vídeo desde el publicador Social.
- Álbum Social propio de miembro.
- Showcase con CTA, guardados, compartir y ficha accionable.
- Rol global `platform_admin` protegido en Supabase.
- Consola global Administración KOMBAX.
- Migraciones 051–056 con preflight/verify/test/rollback.
- Suite estática `test-kombax-20028-implementation.mjs`.

## Changed
- Perfil deportivo deja de equivaler a Competidor KOMBAX.
- Gestor/Coordinación utiliza el Club como identidad pública predeterminada en contexto Club.
- `Mi perfil` de Gestor/Coordinación pasa al Hub del Club.
- Feed/directorio usan el tipo público 20028 (`Miembro`, `Competidor`, etc.).
- Social diferencia claramente Comunidad del Club y actividad KOMBAX.
- Logo/portada Social del Club protegen el branding más reciente durante el backfill 051.
- Herramientas técnicas quedan reservadas a Administración KOMBAX.
- `versionCode` Android sube a `20028`.

## Removed from normal UI
- Badge `SaaS multiclub · Contact sports`.
- Mensajes obsoletos que limitaban KOMBAX Social únicamente a cuentas de alumno.
- Acceso ordinario de Gestor de Club a diagnóstico/certificación técnica global.

## Preserved
- `applicationId com.urbanwarriors.app`.
- Migraciones 037–050 sin reescritura retrospectiva.
- Sin carrito/checkout/pagos/pedidos KOMBAX en Showcase.
- RLS y mutaciones gobernadas.
- Reglas 14+ Social verificadas por Club y alta autónoma 16+.
