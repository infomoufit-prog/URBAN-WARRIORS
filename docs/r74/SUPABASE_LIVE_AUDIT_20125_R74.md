# Supabase live audit · R74 / build 20125

## Estado verificado

- Migraciones R74 live: 4 (260, 261, 262, 263).
- Conexiones Events existentes al auditar: 0.
- Shares de participantes existentes al auditar: 0.
- Índice único histórico `public_event_id` 1:1: ausente.
- Índice multiclub `(public_event_id, owner_club_id)`: presente.
- RLS en shares de participantes: activo.
- ACL directa de la tabla de shares: cerrada.
- Proveedores Showcase duplicados por club: 0.
- Urban Warriors: 1 club, 1 proveedor Showcase, 2 perfiles gestores activos.

## RPC R74

Las RPC privadas auditadas están en `SECURITY DEFINER`, con `search_path` controlado, `anon EXECUTE = false` y acceso autenticado explícito cuando corresponde. `app_kombax_event_public_projection_v220` conserva `anon EXECUTE = true` de forma intencional porque representa la proyección pública autorizada del evento.

## Advisors

El advisor de rendimiento pasó de 219 a 215 foreign keys sin índice después de la migración 263. La diferencia de 4 corresponde a las FKs nuevas de R74 que quedaron cubiertas. Los índices R74 aparecen inicialmente como “unused”, algo esperable mientras no existan conexiones reales.

El advisor global de seguridad conserva un volumen importante de hallazgos históricos/preexistentes (incluyendo tablas RLS deny-all sin policies y funciones SECURITY DEFINER antiguas) y avisa además de que la protección de contraseñas filtradas está desactivada. No se han modificado indiscriminadamente esas superficies dentro de R74 para evitar introducir regresiones fuera de alcance.
