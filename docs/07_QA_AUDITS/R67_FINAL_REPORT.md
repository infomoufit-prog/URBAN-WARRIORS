# KOMBAX R67 · informe final
## Build 20118 — Identity Discovery + Spectator Pilot

### Estado

**QA READY para estabilización en Work y piloto controlado.**

No se declara producción pública cerrada: quedan la QA autenticada/manual con perfiles reales de prueba, firma Android local, hardening global pendiente de Supabase Auth/advisors y la futura fase separada de KOMBAX SaaS Billing.

### Qué se ha cerrado

R67 convierte el onboarding en un recorrido de descubrimiento comprensible para alguien que llega por primera vez desde web, Instagram, campañas o recomendación:

**KOMBAX → entender identidad → conocer beneficios/permisos → ver plan si corresponde → crear cuenta → solicitar/verificar identidad → acceder a capacidades.**

La cuenta base puede existir sin Club ni perfil especializado y funciona como Espectador. Ya no es una pantalla vacía: presenta KOMBAX Social, Showcase y Events como puertas de exploración, mientras mantiene ocultas las áreas privadas de gestión que no le corresponden.

Cada identidad tiene presentación propia: Club, Marca, Federación, Competidor, Profesional, Media/Creador y Espectador. Las identidades comerciales conservan la secuencia de plan antes de solicitud; las no comerciales continúan al registro/perfil correspondiente.

### Descubrimiento comercial

Se conserva y unifica el trabajo R66:

- precios accesibles desde el recorrido de descubrimiento;
- Club muestra Club/Premium/Enterprise antes de solicitar el alta;
- Marca y Federación mantienen plan/ciclo a través de verificación;
- Showcase explica límites y activación de Commerce en contexto;
- Events explica plan/activación cuando una capacidad no está incluida;
- Founder es mensual-only en UI y servidor;
- ninguna de estas rutas activa Billing automático.

### Marketing

Se añadieron deep links de identidad. Ejemplos:

- `?profile=club`
- `?profile=marca`
- `?profile=competidor`
- `?profile=espectador`

La misma estructura sirve para campañas de Instagram, enlaces de socios, QR promocionales o landing pages sin crear un onboarding paralelo.

### Continuidad funcional protegida

La regresión de R67 verifica que siguen presentes:

- Stripe Connect con direct charges;
- compra comercial 18+;
- límites Showcase por plan;
- Seller Center;
- stock y fulfillment;
- refunds parciales/totales;
- Finance Center;
- BI Enterprise;
- Events/Ticketing/QR;
- comunicaciones transaccionales;
- RLS/JWT y separación de ledgers R65;
- migraciones R66 live;
- precios R64.4.

### Evidencia automática

- R67 Release Regression: **22/22**.
- R67 Commercial Continuity: **18/18**.
- R67 Identity + Spectator: **15/15**.
- Pretests históricos críticos: PASS.
- Build Web → dist → Android: **OK, 206 archivos sincronizados**.
- Android preflight: **4/5**; único pendiente: firma local.

La compilación Android debug en este entorno no pudo completarse porque Gradle necesita acceder a `services.gradle.org` y el entorno no resuelve esa red. No se ha detectado un error de compilación de código, pero **no se declara APK generado**.

### Supabase

R67 no necesita migración de base de datos. El backend continúa en R66 y sus dos migraciones constan live. El endpoint `health` se sincronizó a build 20118 y está ACTIVE v26.

El advisor global mantiene deuda histórica de seguridad/hardening no introducida por R67, incluida la protección de contraseñas filtradas de Auth desactivada. No bloquea este paquete UX para piloto controlado, pero debe revisarse antes del lanzamiento público.

### Qué NO se ha hecho

- No se ha activado KOMBAX SaaS Billing.
- No se ha desplegado frontend a Netlify.
- No se ha hecho push a GitHub.
- No se ha publicado en Google Play.
- No se ha generado APK/AAB firmado.
- No se han cambiado los precios vigentes.

### Siguiente gate

Entregar este ZIP a Work y ejecutar `R67_QA_PILOT_CHECKLIST.md` con cuentas ficticias/reales de QA y Stripe test. Corregir únicamente defectos encontrados y congelar después una candidata de piloto.
