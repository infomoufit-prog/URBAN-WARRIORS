# Supabase Advisors · R33.1

## Alcance
R33.1 solo reemplaza el RPC de workspace v197; no crea tablas, claves foráneas ni índices.

## Seguridad
El Advisor de seguridad fue revisado tras la migración. El proyecto mantiene advertencias históricas/generales; por tanto **NO se declara el Advisor globalmente limpio**. La comprobación dirigida del cambio R33.1 sí confirma para los RPCs de licencias/workspace auditados:
- `anon EXECUTE = false`.
- `authenticated EXECUTE = true`.
- `SECURITY DEFINER = true` con `search_path` fijado.
- las funciones conservan comprobaciones internas de autenticación/sujeto/capability según cada RPC.

Entre los avisos generales del proyecto permanece la recomendación de protección de contraseñas filtradas de Auth, que no forma parte del cambio UX R33.1.

## Rendimiento
El Advisor de rendimiento mantiene principalmente INFO históricos por claves foráneas sin índice y numerosos índices aún no usados. También permanece un WARN histórico de índice duplicado en `public.informes_financieros` (`idx_informes_financieros_club_fecha_v145` / `informes_club_generado_v155_idx`).

R33.1 no introduce nuevas tablas/FKs/índices, por lo que no se ha hecho una limpieza global no relacionada con esta corrección.
