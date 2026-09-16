# Changelog · KOMBAX RC13 build 20.095

- Integración/hardening sobre 20.094; sin nueva gran feature.
- Android conserva `event` y `fight` en deep-links públicos KOMBAX con whitelist y validación estricta.
- User-Agent Android y versionCode actualizados a 20095.
- Build web/PWA/cache-busting actualizado a 20095.
- Media de Eventos renueva URL firmada ante fallo y solicita firma fresca al descargar.
- Estado de media no disponible permite reintento sin romper la ficha.
- Service Worker continúa sin cachear recursos firmados cross-origin.
- Netlify/CSP/SPA auditados.
- App Links verificados se mantienen cerrados hasta confirmar SHA-256 de Play App Signing.
- Espectador continúa deshabilitado.
- Tests históricos + 20.095: PASS.
- Build determinista: PASS, 101 archivos web/dist/Android idénticos.
- Android preflight 4/5: firma local pendiente por diseño.
- No se desplegó Netlify, no se publicó Play y no se avanzó `health` productivo antes del frontend.
