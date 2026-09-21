# R40 · SOCIAL / EVENTS VISIBILITY + MIGRATIONS PILOT UX

R40 es la base candidata de continuidad para el piloto. Añade Mi red accionable, audiencias Social con inclusión/exclusión de clubes, visibilidad avanzada de KOMBAX Events y promoción contextual adicional de KOMBAX Migrations. Brand Business Hub R37 ha sido auditado y preservado. Backend R40 live: migraciones 20260904172146 y 20260904172248. Full test/build local: PASS. Android: 4/5, firma local pendiente.

# R39 · CLUB NAVIGATION + MIGRATIONS PILOT UX

R39 es la base actual de continuidad para pruebas locales. La navegación global KOMBAX se preserva; la reorganización afecta exclusivamente a Mi Club.

# KOMBAX · STATUS

## Base de continuidad actual
**20.101 R40 · SOCIAL / EVENTS VISIBILITY + MIGRATIONS PILOT UX**

- Mi red accionable con CTA visible para añadir conexiones.
- Social con audiencia por red/club/federación/clubes seleccionados y exclusiones de clubes.
- Events con visibilidad avanzada independiente de la política de publicación R36.
- KOMBAX Migrations promocionado de forma contextual en Mi Club.
- Brand Business Hub R37 auditado y preservado.
- Backend R40 aplicado en Supabase live.
- R40 targeted QA: PASS 74/74.
- Regresión R39→R32: PASS.
- Full regression/build: exit 0.
- Build/paridad: 189 archivos · web = dist = Android · 0 diferencias.
- Android preflight: 4/5; falta únicamente la configuración de firma local/JKS autorizada.
- No Netlify deploy, GitHub push, Google Play publish ni APK/AAB firmado en este cierre.

Consultar `CONTINUITY_STATUS_20101_R40.md`, `AUDIT_VERIFICATION_20101_R40.md` y `QA_VALIDATION_20101_R40.md`.

## 2026-09-06 · R57 build 20107
QA FREEZE CANDIDATE. Cambio frontend Social: identidad/normas extensas movidas a panel de información. `npm test` PASS; `release:build` PASS; Web/Dist/Android 191/191/191 sin diferencias. APK físico pendiente por acceso Gradle del sandbox. Google Play preflight 4/5 por firma local.
