# R62.8 — Supabase advisor summary

- Performance advisor: **184 unindexed foreign-key findings globales**, sin nuevas FK sin índice detectadas en `kombax_commercial` R62.8. El contador coincide con la base posterior al hardening R62.7; las alertas visibles son deuda histórica de otros módulos.
- Los índices R62.8 recién creados aparecen inicialmente como `unused_index`, algo esperable con 0 solicitudes de ticketing, 0 pedidos y 0 comercio real del piloto en el momento de la auditoría.
- Persiste 1 aviso histórico de índice duplicado en `public.informes_financieros`, ajeno a R62.8.
- Security advisor global **no se declara limpio**. Entre otros avisos históricos, persiste Leaked Password Protection deshabilitado y funciones `SECURITY DEFINER` heredadas expuestas según sus API históricas.
- Las 5 tablas privadas `kombax_commercial` tienen RLS habilitado y privilegios directos de `anon/authenticated` revocados; su acceso de aplicación se realiza mediante RPCs controlados.

Este informe certifica el alcance R62.8; no declara resuelta la deuda histórica global de advisors.
