# KOMBAX R67 · build 20118
## Identity Discovery + Spectator Pilot

R67 cierra la navegación de descubrimiento previa al piloto sin cambiar la arquitectura comercial de R65/R66 ni activar KOMBAX SaaS Billing.

### Cambios principales

- Cada identidad dispone de una presentación previa al alta: Club, Marca, Federación, Competidor, Profesional, Media/Creador y Espectador.
- Las presentaciones explican para quién es la identidad, beneficios, permisos/privacidad y el siguiente paso.
- Club, Marca y Federación mantienen un flujo comercial coherente: presentación → planes → cuenta → solicitud/verificación → petición de plan.
- Una cuenta KOMBAX nueva puede comenzar gratis como Espectador y explorar KOMBAX antes de escoger identidad.
- Home Espectador con accesos principales a KOMBAX Social, Showcase y Events.
- La gestión privada no se presenta al Espectador sin identidad/membresía que la habilite.
- Acceso global a perfiles y planes desde la experiencia de descubrimiento.
- Deep links de marketing por identidad: `?profile=club`, `?profile=marca`, `?profile=federacion`, `?profile=competidor`, `?profile=profesional`, `?profile=media`, `?profile=espectador`. También se admite `?discover=` como alias.
- Las fichas del explicador público pueden llevar directamente a la presentación de la identidad correspondiente.
- Se conserva el descubrimiento contextual de Commerce/Showcase/Events implementado en R66.

### Continuidad garantizada

- Precios R64.4 sin cambios.
- Stripe Connect y direct charges sin cambios.
- Compra comercial 18+ sin cambios.
- Refunds, stock, Finance Center, BI Enterprise, comunicaciones y QR de R65 sin cambios.
- Founder continúa siendo exclusivamente mensual en UI y servidor.
- KOMBAX SaaS Billing continúa fuera de alcance.

### Backend

R67 no añade migraciones de base de datos. El backend comercial sigue siendo R66, con las migraciones live:

- `20260913232901_kombax_r66_commercial_discovery_onboarding`
- `20260913233235_kombax_r66_founder_monthly_guard`

El Edge Function `health` se sincronizó al build 20118 y está activo como versión 26.
