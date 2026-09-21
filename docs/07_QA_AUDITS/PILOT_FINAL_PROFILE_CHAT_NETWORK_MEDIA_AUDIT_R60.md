# KOMBAX 20.110 R60 · Pilot Final Profile / Chat / Network / Media — Audit

Fecha de cierre: 2026-09-09
Estado: **candidato final de piloto para validación física autenticada**.

## Alcance cerrado

Esta entrega consolida el plan visual, conversacional y funcional acordado para PWA, Android y tablet, manteniendo separadas las responsabilidades de Social, Showcase, KOMBAX Assist, Migrations y Soporte KOMBAX.

### Correcciones finales de UX / visual

- KOMBAX Social: hero móvil reencuadrado con más aire superior; la cabeza del peleador principal no debe quedar cortada, mantiene composición desplazada a la derecha y recupera presencia de los peleadores acompañantes.
- KOMBAX Assist / Migrations: dentro de la conversación se usa únicamente el avatar del asistente; la ilustración completa no se repite dentro del flujo del chat.
- Perfiles Social: barra inferior de acciones reconstruida como layout responsive acotado; `Añadir a mi red` ya no sale del viewport.
- Mi Red: eliminado el selector nativo gris `Perfil`; solo aparece un control de identidad integrado cuando realmente existen varias identidades utilizables.
- Showcase: la moderación de mensajes deja de insertar el texto visible `Denunciar` en cada burbuja; la acción queda secundaria/iconográfica.
- Actividad KOMBAX del perfil: las publicaciones con foto o vídeo muestran el media asociado. Vídeos con `playsinline`/controles y apertura inmersiva; fotos con apertura inmersiva.
- La navegación inferior móvil continúa oculta; el menú lateral es la superficie principal de navegación móvil.
- Se preservan las mejoras previas de Events (cache/prefetch/continuidad), álbumes fullscreen y safe areas.

### Correcciones funcionales

- Los miembros verificados/activos de un club pueden gestionar su propia red KOMBAX sin necesitar la capacidad `social.publish` ni permisos administrativos del club.
- Se separa la autorización de red de la autorización de publicación.
- La lectura de publicaciones de perfil incluye metadatos/media autorizado para evitar tarjetas solo textuales cuando existe un vídeo/foto.
- El borrado de historial de Migrations/Assist acepta correctamente el alias `management`, mantiene Soporte fuera de ese borrado y preserva el consumo de allowance ya contabilizado.
- Las identidades ficticias QA/DEMO detectadas en directorio público se mantienen para QA interno pero con `visible=false` para el piloto.

## Arquitectura conversacional preservada

- **Social:** mensajería entre identidades KOMBAX.
- **Showcase:** conversaciones vinculadas a producto/servicio/oportunidad.
- **KOMBAX Assist:** copiloto IA de gestión para Club, Federación y Marca, en solo lectura durante el piloto.
- **Migrations:** asistencia especializada de migración para Club/Federación.
- **Soporte KOMBAX:** vía técnica/formal, ticket + chat guiado + posible revisión/verificación humana.

Soporte KOMBAX no se sustituye por Assist y no comparte su contador de conversaciones.

## Evidencia de construcción

- `npm test`: PASS completo.
- QA final Assist/Conversaciones: 28/28 PASS.
- QA final Profile/Chat/Network/Media: 24/24 PASS.
- QA R60 Migrations/Guide/History: 32/32 PASS.
- Legal release gate: PASS.
- Build: `197 archivos · web = dist = Android`.
- Android preflight: 4/5; único pendiente: firma local (`android/keystore.properties`).
- No se incluyen secretos, keystore ni `keystore.properties` en el artefacto.

## Estado de piloto vs. producción general

La entrega está cerrada como **candidato final de piloto**. La validación física autenticada en Android/PWA/tablet sigue siendo obligatoria antes de declarar producción general.

La auditoría global de Supabase mantiene backlog histórico de hardening que no ha sido barrido de forma masiva en este hotfix para evitar alterar contratos antiguos justo antes del piloto. Debe tratarse como carril separado de estabilización:

- Security: 107 avisos INFO `RLS enabled no policy`.
- Security: 42 WARN de funciones `SECURITY DEFINER` ejecutables por `anon` (revisar cuáles son intencionadamente públicas).
- Security: 383 WARN de funciones `SECURITY DEFINER` ejecutables por usuarios autenticados (revisar grants/ownership por contrato).
- Auth: protección contra contraseñas filtradas desactivada.
- Performance: 167 FKs sin índice de cobertura; 189 índices sin uso; 1 índice duplicado detectado.

No se han aplicado cambios globales automáticos sobre esos cientos de objetos en esta entrega final porque requieren auditoría por contrato y podrían romper módulos históricos.

## Referencias de remediación Supabase

- RLS sin policy: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
- SECURITY DEFINER / anon: https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable
- SECURITY DEFINER / authenticated: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- Protección de contraseñas filtradas: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- FKs sin índice: https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys
- Índice duplicado: https://supabase.com/docs/guides/database/database-linter?lint=0009_duplicate_index
