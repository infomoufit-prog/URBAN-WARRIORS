# KOMBAX RC13 build 20.096 · Events Premium Visual Identity · Validation

## Base
20.095 Integration / Hardening Final Candidate.

## Cambios funcionales
Ninguno en backend/modelo de negocio. Esta build es una mejora visual acumulativa.

## Cambios visuales certificados
- icono de arena propio en navegación;
- iconografía semántica por categoría;
- paleta rojo KOMBAX + cian/violeta neon;
- asset local de malla neon;
- hero premium con motion ambiental;
- cards, tabs, search, detail y landing pública mejorados;
- Fight Cards con iluminación broadcast;
- sponsors/partners/highlights con glass y edge glow;
- interacción táctil específica;
- ocho plantillas share/Fight/Result rediseñadas localmente;
- reduced-motion preservado.

## QA
- Sintaxis `icons.js`: PASS.
- Sintaxis `kombax-events.js`: PASS.
- `test-kombax-20095-integration-hardening.mjs`: PASS.
- `test-kombax-20096-events-premium-visual.mjs`: PASS.
- `npm test`: PASS completo.
- `npm run build`: PASS.
- build determinista: `web = dist = Android`, 102 archivos.
- `npm run release:legal-gate`: PASS.
- Android preflight: 4/5; solo firma local ausente del paquete por diseño.

## Backend
No hay migraciones nuevas. No se ha modificado ni desplegado Supabase productivo.

## Deploy
No se ha ejecutado Netlify ni Google Play.
