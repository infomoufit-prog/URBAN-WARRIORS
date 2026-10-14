# KOMBAX — Estado acumulativo al cierre de FASE 5C

Base: acumulativo FASE 5B validado por SHA256. Fases 0–5B conservadas.

F5C implementada localmente: subida de JPEG desde el panel de Instagram mediante Social, selección y reuso de publicación previa, enlaces HTTPS en el texto, confirmación separada de publicación en Meta; cotización facial de categorías General/VIP antes de Stripe; preflight de requisitos comerciales R269.

Supabase: R269, R269b, R269c aplicadas. Ningún dato económico modificado, sin categorías activadas. R265/R266/R268 siguen vigentes.

QA: F5C 26/26; F5B 40/40; Material/Showcase 28/28; navegación premium 94/94; Meta mock 23/23, runtime 8/8. E2E Instagram, pagos VIP y Federación pendientes por inexistencia de cuentas/recursos reales autorizados para QA.

Prohibiciones: SIN GitHub push; SIN Netlify deploy; SIN envíos a Instagram; SIN Stripe real. Interno R118/build 20178 sin cambios.

## 14/10/2026 — Entrega final acumulativa R270 · PWA universal
- Instalador común para personalidades independientes y todas las funciones del club.
- Cabecera móvil y barra lateral, manejo de `beforeinstallprompt`/`appinstalled`, estado instalado, iOS Safari y Android wrapper.
- Cache-buster R270 y SW, sin cambiar build interno 20178.
- 31/31 pruebas R270, 654 recursos sincronizados; gate legal PASS, build.mjs PASS.
- `release:build` bloqueado en entorno local por ausencia de dependencia `@electric-sql/pglite`; no certificación de Netlify CI desde esta copia.
- Sin push, deploy, cobros reales ni publicaciones Instagram.
