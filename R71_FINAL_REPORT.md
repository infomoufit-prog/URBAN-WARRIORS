# KOMBAX R71 · Sidebar Product Accordions

**Build:** 20122  
**Version:** `2.0.0-rc.13-r71-sidebar-product-accordions`  
**Base:** R70 build 20121

## Implementación

Se sustituye la presentación plana de los centros privados por dos acordeones de producto en la barra lateral, usando el mismo lenguaje de interacción de **Mi Club**:

- **KOMBAX Events ▸**
  - Explorar Eventos
  - Mis Eventos *(solo cuando el usuario tiene permiso de organización/gestión)*
- **KOMBAX Showcase ▸**
  - Explorar Showcase
  - Mi Showcase *(solo cuando el usuario tiene permiso de vendedor/gestión)*

Los acordeones se abren automáticamente cuando la ruta activa pertenece al módulo público o a su centro privado y recuerdan la preferencia de apertura del usuario mediante `localStorage`.

## Lo que no cambia

- Rutas públicas y privadas existentes.
- Permisos de `Mi Showcase` y `Mis Eventos`.
- Club Basic: 15 productos y Commerce opcional 12 €/30 días.
- Precios de KOMBAX Events, Ticketing y destacados.
- Seller Center R68.
- Centro de Eventos R69.
- Supabase/RLS/Stripe/contratos: sin cambio de esquema ni migración nueva.

## QA

Baterías específicas: **92/92**.

- Release regression: 22/22
- Commercial continuity: 18/18
- Identity + Spectator: 15/15
- Showcase Seller Center: 13/13
- Events Operations Center: 15/15
- Sidebar Product Accordions: 9/9

`npm run build`: PASS.  
Sincronización: **206 archivos · web = dist = Android**.

## Android

Preflight: **4/5**. El único pendiente es `android/keystore.properties`, que debe permanecer local y no se incluye en el paquete.

No se declara APK/AAB R71 generado ni firmado.

## Despliegue

No se ha desplegado frontend en Netlify, no se ha hecho push a GitHub y no se ha publicado en Google Play. No era necesaria una migración Supabase para este cambio de navegación.
