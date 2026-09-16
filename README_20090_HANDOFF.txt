KOMBAX RC13 build 20.090 · KOMBAX EVENTS FOUNDATION

BASE: 20.089 FULL · Finance User Language Audit
ESTADO: build completa candidata de Fase 1; no desplegada automáticamente.

VALIDADO:
- npm test: PASS
- npm run build: PASS
- web = dist = Android: determinista
- Android versionCode: 20090
- Health marker: 20090
- KOMBAX Eventos separado de Mi Club > Eventos
- assets visuales offline incluidos

SUPABASE:
- Nueva migración: supabase/migrations/159_kombax_events_foundation_20090.sql
- Verificación: supabase/verification/verify_159_kombax_events_foundation_20090.sql
- Rollback seguro: conserva datos y cierra RPCs; no borra tabla.
- La migración NO ha sido aplicada automáticamente a producción/piloto desde este trabajo local.

CONTINUIDAD:
Leer PROMPT_MAESTRO_CONTINUIDAD_20090.md antes de Fase 2.
