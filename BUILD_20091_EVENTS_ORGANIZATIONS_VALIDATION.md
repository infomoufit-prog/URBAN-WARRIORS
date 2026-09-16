# KOMBAX RC13 build 20.091 · Validation

## Resultado
- `npm run test:20091`: PASS.
- `npm run build`: PASS.
- Suite histórica completa: PASS.
- Build determinista: `web = dist = Android` para 91 archivos web.
- JavaScript: `kombax-events.js` y `repositories.js` pasan comprobación de sintaxis Node.
- Health/build marker: 20091.
- Android `versionCode`: 20091.

## Invariantes específicos de Fase 2
- `Mi Club > Eventos` continúa en `repos.events` y `public.eventos_competicion`.
- KOMBAX Eventos utiliza `public.kombax_eventos_publicos` + `public.kombax_evento_entidades`.
- La migración 160 no lee, copia ni une `public.eventos_competicion`.
- Club Básico no recibe `events.public.organize` por herencia de `club_saas`.
- Federación institucional queda preparada y reconciliada para organizar.
- Gestión compartida de organizador/coorganizador requiere invitación aceptada + entitlement.
- Entidades externas pueden figurar como aval/colaborador/patrocinador pero no obtener gestión.
- Logos/identidades KOMBAX abren perfiles públicos.
- Assets de organización/patrocinio son locales; no requieren API key.
- Animaciones respetan `prefers-reduced-motion`.

## Backend live
La migración 160 está incluida pero NO se ha ejecutado automáticamente contra Supabase productivo.
