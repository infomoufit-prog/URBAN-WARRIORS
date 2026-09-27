# KOMBAX · Fase 0 · Auditoría de base maestra R81 build 20134

## Propósito

Esta Fase 0 se ejecuta **antes de implementar el Plan Maestro de ampliación**. Su objetivo es certificar una base acumulativa limpia, reproducible y congelable sobre la que iniciar el bloque previo de diseño y contenidos.

Base auditada de entrada:

- `KOMBAX_20133_R81_TAP_TO_PAY_ANDROID_IPHONE_ACCUMULATIVE_FINAL.zip`
- SHA-256 verificado: `423e4b7293edd868011433eb08916e3357c5754c98e8bc0d54179c298c7f6f96`
- Integridad ZIP: PASS, sin errores CRC.

Base de salida de Fase 0:

- Release funcional: **R81**
- Build acumulativo corregido: **20134**
- Rol: **base maestra auditada / freeze base para la siguiente fase**

No se han iniciado todavía KOMBAX Guías, KOMBAX Consultoría, KOMBAX Formación ni los assets del siguiente bloque.

## Hallazgo bloqueante corregido

La auditoría reprodujo en el ZIP maestro la incidencia observada en Android Studio:

`KombaxTerminalManager.java` dependía de `BuildConfig.DEBUG` para decidir si Stripe Terminal debía descubrir un lector Tap to Pay simulado.

Ese símbolo no quedaba disponible de forma fiable en el contexto observado y provocaba el error de compilación `cannot find symbol: variable BuildConfig`.

### Corrección aplicada

La lógica se ha sustituido por la bandera Android estable del propio `ApplicationInfo`:

```java
boolean simulated =
    (appContext.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
```

Además se incorporó `android.content.pm.ApplicationInfo` y un gate automatizado que falla si vuelve a aparecer `BuildConfig.DEBUG` en el Terminal Manager.

La corrección mantiene el comportamiento previsto:

- build/debuggable -> permite simulación;
- build de producción no debuggable -> lector real;
- no se importa ni usa el `BuildConfig` de Stripe;
- no se modifica el flujo de PaymentIntent, ConnectionToken, Stripe Connect ni webhook.

## Versionado y coherencia de release

Para evitar distribuir dos bases diferentes con el mismo `versionCode`, Fase 0 avanza el build acumulativo de **20133 a 20134**, conservando R81 como release funcional.

Se han alineado:

- `web/config.js`;
- service worker/cache marker;
- cache-busters del app shell y páginas públicas;
- Android `versionCode` y User-Agent KOMBAX;
- iOS `CFBundleVersion` y `CURRENT_PROJECT_VERSION`;
- `health` source;
- gates acumulativos que fijaban la identidad de la release actual.

No se ha alterado el modelo comercial ni se han añadido funciones del Plan Maestro.

## Auditoría por área

| Área | Estado Fase 0 | Evidencia / observación |
|---|---|---|
| Integridad del ZIP | PASS | CRC correcto + SHA-256 de entrada verificado |
| Frontend / PWA | PASS | `release:build` completo y app shell build 20134 |
| Paridad de build | PASS | 466 archivos; `web = dist = Android assets` por SHA-256 |
| Legal gate | PASS | `npm run release:legal-gate` |
| Regresión acumulativa | PASS | `npm test` completo |
| R81 Tap to Pay | PASS | 41/41 checks |
| Fase 0 | PASS | 11/11 checks específicos |
| I18N | PASS | auditoría R79/R78 acumulativa; 0 unresolved; 8 idiomas activos |
| Showcase | PASS baseline | seller center, Commerce/Stripe y separación Explore/Mi Showcase preservados por regresión |
| Events | PASS baseline | operaciones, ticketing, QR, centros privados y comunidad preservados |
| Finanzas | PASS baseline | Finance Premium, reporting R77, pagos R80 y Terminal R81 preservados |
| Social / Discovery | PASS baseline | discovery de perfiles/peleadores R36 preservado |
| Perfiles | PASS baseline | matriz de perfiles, capacidades y hubs acumulativos preservados |
| Multiclub / multientidad | PASS baseline | R74/R75 y aislamiento de contexto preservados |
| Roles / privacidad / menores | PASS | gates acumulativos de seguridad, privacidad y compra adulta |
| Supabase R81 live | PASS | migración R81 presente; tablas/RPC principales presentes; funciones de pago ACTIVE |
| RLS Terminal | PASS | `terminal_locations_r81` y `terminal_sales_r81` con RLS ON, sin policies públicas por diseño |
| Stripe Terminal | PASS backend/source | `stripe-terminal` ACTIVE + JWT; webhook v267 presente |
| Stripe SEPA | PASS backend/source | `stripe-sepa` ACTIVE + JWT; R80 preservado |
| Stripe Checkout/Connect | PASS backend/source | funciones ACTIVE; regresión comercial preservada |
| Android source | CORREGIDO/PASS estático | dependencia `BuildConfig.DEBUG` eliminada |
| Android preflight | 4/5 | único pendiente: firma local `android/keystore.properties`, excluida deliberadamente |
| Android compilación Gradle en contenedor | GATE EXTERNO | Gradle no llega al compilador por DNS/red bloqueada al descargar `services.gradle.org`; no es un error de Java observado |
| iOS source | PASS estático | Swift 6.2.1 `swiftc -parse` en las 3 fuentes + plist/entitlements válidos |
| iOS build/firma | GATE EXTERNO | requiere macOS/Xcode, Apple Developer, entitlement y provisioning |
| Netlify build | PASS local | se ejecutó el mismo `npm run release:build` configurado para release |
| Netlify publicación real | NO EJECUTADA | Fase 0 certifica paquete; no cambia sitio/credenciales |
| GitHub push | NO EJECUTADO | paquete preparado; no se modifica repositorio remoto en Fase 0 |

## Backend Supabase live auditado

Se confirmó en el proyecto actual:

- migración `kombax_r81_terminal_tap_to_pay` aplicada;
- RPC `app_stripe_payment_methods_status_r81` presente;
- RPC `app_stripe_terminal_toggle_r81` presente;
- reconciliador `app_stripe_event_apply_v267` presente;
- `kombax_payments.terminal_locations_r81` presente;
- `kombax_payments.terminal_sales_r81` presente;
- `stripe-terminal` ACTIVE con JWT;
- `stripe-webhook` ACTIVE, autenticado por firma Stripe;
- `stripe-connect`, `stripe-checkout`, `stripe-sepa`, `stripe-refund` y `stripe-account-finance` ACTIVE;
- `health` actualizado a build 20134.

No se ha realizado ningún cargo real para certificar Fase 0.

### Advisors Supabase

No se detectó un nuevo bloqueo específico de R81.

- Las tablas Terminal aparecen como `RLS enabled no policy`: es **intencional**, porque su acceso directo se mantiene deny-by-default y se opera por RPC/service-role.
- Los RPC públicos autenticados de lectura/toggle aparecen como `SECURITY DEFINER`; conservan comprobación explícita de `auth.uid()` y permisos de identidad. No se ha abierto acceso anónimo.
- Los avisos de índices no usados / FKs sin índice son informativos en este punto y no justifican una migración destructiva dentro de Fase 0.
- Existe al menos un aviso histórico de índice duplicado fuera de R81; se conserva para una fase de mantenimiento/performance, no se modifica aquí.

## Seguridad de paquete

Fase 0 debe cerrarse sin:

- `sk_live_*` / `sk_test_*` reales;
- `.env` reales;
- `android/keystore.properties`;
- JKS/keystore privados;
- certificados Apple, `.p12`, `.pfx` o provisioning profiles;
- connection tokens o PaymentIntent client secrets persistidos en documentación/artefactos de release.

`android/app/google-services.json` permanece como configuración cliente Firebase de la app Android; no es la clave privada de firma y no sustituye la gestión de secretos backend.

## Estado funcional que se congela

Fase 0 **no implementa** todavía los cambios del Plan Maestro. Se congelan como alcance pendiente para los bloques posteriores:

1. Showcase: nueva experiencia de compra con CTA Comprar/Carrito/Checkout final.
2. KOMBAX Finance multientidad y reorganización de Finanzas Premium en acordeones.
3. Nueva Home post-login con cuatro tarjetas y **Mi espacio siempre en última posición**.
4. KOMBAX Guías con assets, biblioteca, dossiers y PDFs navegables/descargables.
5. KOMBAX Consultoría con capa propia, catálogo, costes y flujo de servicio.
6. KOMBAX Formación privada por entitlement para federación/colegio profesional piloto.
7. Social -> Descubrir: evolución del directorio competitivo y pantalla/listado de rankings.
8. Integraciones futuras entre directorio de peleadores y KOMBAX Events.

## Conclusión de Fase 0

La base R81 ha sido auditada y el único defecto bloqueante reproducido de Android (`BuildConfig.DEBUG`) se ha corregido en fuente y protegido mediante test de regresión. Build, legal gate, i18n y regresión acumulativa pasan sobre build 20134.

La base resultante puede utilizarse como **única entrada para el bloque previo de diseño y contenidos**, una vez entregado y verificado el ZIP acumulativo de Fase 0.
