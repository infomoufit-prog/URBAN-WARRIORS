# KOMBAX 20.056 · CLUB NAVIGATION BRANDING

## Objetivo
La navegación interna del Club debe mostrar la identidad visual del club activo y no usar KOMBAX como fallback de logo.

## Implementación
- Prioridad 1: `session.club.logo_url` válido.
- Prioridad 2: logo configurado del tenant principal cuando el slug coincide (Urban Warriors en la configuración actual).
- Si otro club no tiene logo publicado: fallback neutro con iniciales del club.
- El shell interno nunca usa el símbolo KOMBAX como fallback del logo del club.
- La marca KOMBAX se conserva separada como marca tecnológica en la barra superior.
- La marca de agua del área del club se desactiva si no existe un logo real del club.

## Validación
- Test específico `test-kombax-20056-club-navigation-branding.mjs`: PASS.
- `npm test`: PASS.
- `npm run build`: PASS.
- Builder: 65 archivos · web = dist = Android.
- No requiere migración Supabase.

## Estado
Candidata para validación visual/local antes del despliegue.
