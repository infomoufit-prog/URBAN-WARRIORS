# KOMBAX 20.055 · MVP PROFILE SCOPE · VALIDATION

Fecha: 2026-08-19

## Alcance
- Competidor queda temporalmente deshabilitado durante el MVP mediante `disabled:true`.
- El código y continuidad Miembro→Competidor se conservan para reactivación futura.
- Identidades oficiales solicitables en MVP: Club, Marca y Federación.
- Miembro continúa como identidad Social natural; Dirección/Gestor/Coordinación/Equipo/Monitor continúan como roles internos de Club.
- No hay cambio de esquema Supabase en esta versión.

## Validación automática
- `node scripts/test-kombax-20055-mvp-profile-scope.mjs`: PASS.
- `npm test`: PASS completo.
- `npm run build`: PASS.
- Builder: 65 archivos · web = dist = Android.
- Comparación SHA-256 independiente: web=65, dist=65, Android=65; 0 missing, 0 extra, 0 diff.
- Árbol web SHA-256: `d215d888ce9a7b7d3dd79f58bbc19f8fdeea8a13c461931b8ed4bd203e050547`.
- Secret scan estrecho: 0 claves privadas, 0 JWT service_role, 0 JKS/keystore.properties.
- Android preflight: 4/5; único pendiente intencional = firma local privada (`android/keystore.properties`).

## Pendientes antes de producción pública
- Validación manual local PC/móvil de la 20.055.
- Confirmar cuenta Administrador KOMBAX y recorridos principales.
- Firma Android local para APK/AAB release.
- GitHub/Netlify/Google Play aún no ejecutados desde esta build.
- Security/Performance Advisor conserva avisos históricos ya inventariados; leaked-password protection continúa pendiente.
