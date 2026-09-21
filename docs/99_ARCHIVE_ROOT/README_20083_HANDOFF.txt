KOMBAX RC13 build 20083 · FINAL FINANCE + WORKSPACE CONTEXT ISOLATION

OBJETIVO
- Resolver mezcla privada entre identidades/clubes en una misma cuenta multi-rol/multi-identidad.
- Cerrar Finance Premium 2.0 con un gate final independiente antes de recurrencia real.

NUEVO
- migration 147: aislamiento club + identidad activa para perfiles, inbox, mensajes, leído, Mi red y header.
- hardening cliente: selectedSocio tenant-scoped, limpieza de intents privados y sincronización push marcada por club.
- frontend context-isolation-20083.js cargado antes de app.js.
- audit RPC 147 con contadores, sin contenido de chats.
- migration 148: finance_pilot_live_enabled + readiness + auto-cierre + activación idempotente con frase exacta.
- Finance UI muestra FINAL PILOT GATE, pero no activa recurrencias reales desde un clic.

COMPATIBILIDAD
- Feed/directorio/Showcase públicos siguen siendo globales.
- KOMBAX global conserva perfiles directos y sus chats globales.
- No se reescriben ni borran chats históricos.
- No se reescriben pagos/recibos/cargos históricos.

PRODUCCIÓN
- Este ZIP es un candidato de código. Las migraciones 143-148 NO se han aplicado por este trabajo.
- No se ha activado ningún flag financiero ni la recurrencia real.

VALIDAR
- Ejecutar scripts/test-kombax-20079... hasta scripts/test-kombax-20083...
- Seguir docs/KOMBAX_20083_INSTALL_ORDER.md
