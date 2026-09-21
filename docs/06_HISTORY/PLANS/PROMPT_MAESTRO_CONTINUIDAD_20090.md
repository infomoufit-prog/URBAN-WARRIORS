# CONTINUIDAD · KOMBAX RC13 build 20.090 · EVENTS FOUNDATION

## Fuente de verdad
Esta build deriva de 20.089 FULL · Finance User Language Audit. Conserva Finance Premium, Social, Showcase, Owner, Android/PWA/Netlify y todo el hardening anterior.

## Decisión crítica
Hay dos dominios de eventos y NO deben fusionarse:
- **Mi Club > Eventos**: internos del club, incluidos en Club Básico, backend histórico `eventos_competicion`.
- **KOMBAX Eventos**: público/transversal, nueva capa global `kombax_eventos_publicos`.

## Implementado en 20.090
Fundación de navegación, UI premium animada, categorías, filtros, ficha pública base, feature flag, repositorio independiente, schema/RPC seguros y plantillas SVG locales offline.

## Assets
`web/assets/events/template-manifest.json` enumera plantillas locales. No requieren API key. El motor de composición con fotos/datos se implementará en fases posteriores.

## Siguiente fase
20.091: ficha pública avanzada + organizadores/coorganizadores/avales/colaboradores/patrocinadores, logos vinculados a perfiles y permisos multiidentidad.

## Reglas que se mantienen
No abrir recurrencias financieras ni gates cerrados. Nada destructivo. Históricos preservados. No exponer flags/RPC/builds en UX final.
