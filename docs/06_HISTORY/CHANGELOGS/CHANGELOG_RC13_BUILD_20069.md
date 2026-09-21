# KOMBAX RC13 build 20069

## Administración global

- Contexto temporal por Club, cuenta o perfil directo, ligado al Owner autenticado, `session_id` Auth y sesión administrativa v110.
- Expiración de 15 minutos, cierre explícito e invalidación al cerrar la sesión Owner.
- Sin membresías artificiales, contraseñas de terceros ni suplantación silenciosa.
- Búsqueda unificada y proyección privada controlada por RPC.
- Auditoría privilegiada con actor, entidad, acción, resultado, motivo y fecha.
- Operaciones sensibles iniciales: activación de Club y estado de moderación de perfiles directos.

## Moderación

- Conserva el rol global separado del Owner.
- Decisiones: `allowed`, `review`, `hidden`, `warning`, `suspended`, `escalated`.
- Motivo estructurado, confianza, evidencia y tipo de actor preparados para IA controlada.
- Sin acceso de Moderador a Finanzas, cobros, recibos, documentos privados, configuración o roles críticos.
- La IA futura deberá usar RPC limitadas; las tablas permanecen cerradas.

## Continuidad

- Conserva Owner por contraseña y `app_kombax_platform_admin_password_complete_v110` sin OTP.
- Conserva Showcase para Club, Marca, Federación y Competidor de build 20068.
- No cambia correos Auth, usuarios, membresías ni contenido existente.

## Supabase LIVE y QA

- Migración funcional `114_kombax_global_admin_moderation_20069.sql` aplicada una vez.
- Correcciones incrementales `115` y `116` aplicadas sin repetir ni editar el historial LIVE: alias del resultado unificado y lectura del estado de cuenta desde Auth.
- Prueba transaccional PASS para Owner, contexto temporal de Club, aislamiento del Moderador y denegación al usuario ordinario; toda la prueba se revirtió.
- Las tres tablas nuevas tienen RLS y carecen de DML directo para `anon` y `authenticated`; el acceso se realiza exclusivamente mediante RPC autorizadas.
- Asesores de Supabase revisados. Los avisos de las tablas nuevas son informativos (`RLS enabled/no policy` por diseño deny-by-default e índices aún sin uso por ser nuevos).
