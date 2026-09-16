# Changelog · KOMBAX RC13 build 20.101 · Demo Event Showcase

- Evento público `Noche de Impacto · Barcelona · DEMO QA` instalado en el Supabase real.
- Mismo modelo, lectores y pantalla de detalle que un evento normal.
- 12 participantes ficticios y 6 Fight Cards reales en el dominio Events.
- Club Fénix Elite · DEMO como organizador visual y Federación Nova Combat · DEMO como aval.
- Banco multimedia local completo para portada, Fight Card, press day, recinto, álbum, resultados y highlights.
- Auto-hidratación Owner de 10 imágenes hacia el bucket privado oficial en la primera entrada compatible.
- Seed/cleanup Owner-only, idempotentes, sin tablas paralelas de demo.
- Corrección arquitectónica: assets demo se leen a través de backend/repositorio, sin `fetch()` directo en módulo UI.
- Web/PWA/Android versionados a 20101.
- `npm test` y `npm run build` PASS; 132 archivos web/dist/Android idénticos.
