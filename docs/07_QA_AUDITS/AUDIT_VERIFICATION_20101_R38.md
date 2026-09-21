# KOMBAX 20.101 R38 · Audit Verification

## Separación de producto
Verificado en código y tests:
- Ruta visible `KOMBAX Assist`.
- Ruta visible `KOMBAX Migrations`.
- Migrations abre conversación + cargador de documentos directamente.
- Assist no ofrece “Nuevo chat” customer-side; correo primero y chat solo si ya está activado.
- La API impide saltarse la UI para autoactivar Assist.

## Backend live
- Migraciones 227–234 aplicadas en Supabase live.
- Edge Function `kombax-assist-r38` live, versión 2, SHA `7afcd0db2672edfe9f3809a3ca638ee201b861e72c48d0cd7dae961a804a5fd3`.
- `app_kombax_assist_turn_reserve_v227`: `authenticated=true`, `anon=false`, `service_role=false` para EXECUTE.
- `app_kombax_customer_ops_mutate_v233`: customer-safe; v213 revocada para authenticated.
- Tablas R38 de turnos/chat/análisis sin filas reales durante el cierre.

## Rendimiento y seguridad
- Migration 234 cubre las cinco FKs R38 que el performance advisor señaló sin índice.
- Tras 234 ya no aparecen esos avisos `unindexed_foreign_keys`; los índices pueden figurar como `unused_index` al no haber tráfico todavía.
- Persisten avisos históricos de advisors en otras áreas. No se ocultan ni se declaran resueltos por R38.

## QA/build
- R38: 67/67.
- R37→R32: todas las suites dirigidas pasan.
- Full `npm run build`: exit 0.
- Build: 189 archivos.
- Paridad independiente: web 189 = dist 189 = Android 189, 0 diferencias.
- Hash agregado web: `3a675dc81f60371ddaa7c08392c9c224d7c6ddc125bb5f57993eb16ddfe3ebd0`.

## Android
- Preflight 4/5; firma local deliberadamente fuera del paquete.

## No realizado
- No Netlify deploy.
- No GitHub push.
- No Google Play publish.
- No APK/AAB firmado.
