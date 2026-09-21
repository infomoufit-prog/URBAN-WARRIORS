# R67 · estado Supabase live

Proyecto verificado: `poggsobhtutbuagjiydc`.

## Estado de migraciones

R67 es una entrega UX/navegación y no crea una nueva migración. Las dos últimas migraciones funcionales de este trabajo son las de R66:

1. `20260913232901_kombax_r66_commercial_discovery_onboarding`
2. `20260913233235_kombax_r66_founder_monthly_guard`

Se verificó que ambas constan en el historial live.

## Comprobaciones R66/R67 relevantes

- Marca queda incluida en el selector de organizadores de Events, manteniendo entitlements como autoridad real de acceso.
- El contexto de Seller Center expone la identidad comercial solo después de autorización del gestor.
- Los guards internos de onboarding comercial no son ejecutables por `anon` ni `authenticated`.
- Founder está endurecido como modalidad mensual tanto en solicitud como en onboarding/activación.
- R67 no añade tablas, políticas RLS, RPCs comerciales ni cambios de cobro.

## Health

- Edge Function: `health`
- Estado tras despliegue: ACTIVE
- Versión: 26
- Build reportado: 20118
- `verify_jwt=false` por tratarse del endpoint público de health.

## Advisors

El advisor global conserva avisos históricos del proyecto que no han sido introducidos por R67. Entre ellos hay avisos sobre funciones `SECURITY DEFINER` expuestas de generaciones anteriores y la protección de contraseñas filtradas de Supabase Auth desactivada.

R67 no amplía esa superficie. Para un piloto controlado se registra como deuda de hardening; antes de lanzamiento público se debe hacer una revisión específica de cada función pública intencional/no intencional y activar la protección de contraseñas filtradas cuando el plan/configuración de Auth lo permita.

Referencia de Supabase para contraseñas: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
Referencia del linter: https://supabase.com/docs/guides/database/database-linter
