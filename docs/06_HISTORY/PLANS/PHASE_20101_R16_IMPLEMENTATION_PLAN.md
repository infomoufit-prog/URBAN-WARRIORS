KOMBAX 20.101 R16 · EVENT MANAGEMENT UX CLEANUP

BASE
- Working base: KOMBAX 20.101 R15 Responsive Visual Tuning.

MISSION
- Remove the oversized management-action toolbar from event detail.
- Keep the public event experience visually clean.
- Expose all organizer tools through one compact “Gestionar evento” control anchored to the event hero.
- Use a contextual popover on desktop/tablet and a bottom-sheet style panel on mobile.

SCOPE
1. Replace management buttons in the sticky modal actions with one hero-level management launcher.
2. Group management actions into:
   - Evento: Constructor, Editar ficha, Portada / encuadre.
   - Competición: Participantes, Crear combate / Fight Card.
   - Contenido: Álbum, Organización.
   - Utilidades: Visual Studio.
3. Preserve public actions separately: Me interesa, Compartir, QR.
4. Add accessible open/close behavior (aria-expanded, Escape, outside/scrim close).
5. Responsive behavior:
   - Desktop/PWA: compact popover top-right.
   - Tablet: compact two-column panel.
   - Mobile: bottom-sheet panel with safe-area padding.
6. Preserve all R14 Event Creator and R15 responsive behavior.

NO BACKEND CHANGES
- No Supabase migrations, SQL, RLS or data changes.
- Existing can_manage remains the source of truth.

FILES EXPECTED TO CHANGE
- web/js/modules/kombax-events.js
- web/css/kombax-events.css
- web/index.html
- web/service-worker.js
- package.json
- scripts/test-kombax-20101-event-management-r16.mjs
- historical cache-bust assertions as needed.

QA
- Dedicated R16 test.
- Full npm run build.
- Verify web = dist = Android.
- Android preflight.

CLOSURE CRITERIA
- No management action wall in event footer.
- One “Gestionar evento” button visible only when event.can_manage is true.
- Every previous management action remains reachable.
- Desktop/tablet/mobile interaction is responsive and accessible.
- R14 Event Creator, Fight Cards, Album and R15 responsive visual tuning remain intact.
