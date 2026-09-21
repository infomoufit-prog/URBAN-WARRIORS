# KOMBAX R81 build 20133 · Informe final

## Objetivo

Añadir cobro presencial móvil a KOMBAX sin duplicar el motor financiero, preservando Stripe Connect, tarjeta online y SEPA. R81 añade un tercer método: **Tap to Pay / Cobro presencial**.

## Resultado funcional

### KOMBAX Payments

Cada identidad comercial conserva una única cuenta Stripe Connect y puede disponer, según permisos y servicio, de:

- tarjeta online;
- SEPA;
- Tap to Pay / cobro presencial;
- fallback web por QR/enlace.

Identidades cubiertas:

- Club;
- Federación;
- Marca / vendedor Showcase;
- Organizador profesional de eventos.

### Flujo Android

La app Android mantiene la interfaz WebView/PWA y añade un puente nativo con Stripe Terminal 5.8.1. El backend crea el PaymentIntent y limita el contexto comercial; el móvil procesa el `client_secret` con Tap to Pay y devuelve el resultado al frontend. La reconciliación final depende del webhook Stripe.

### Flujo iPhone

Se incorpora una variante iOS basada en SwiftUI + WKWebView + Stripe Terminal. El mismo Payment Center detecta el puente `kombaxTerminal` cuando exista app instalada.

Antes de que la app iOS esté distribuida, Safari/PWA ofrece QR o enlace Stripe Checkout. Una web normal no convierte el NFC interno del iPhone en un lector Tap to Pay.

### Backend

R81 incorpora:

- Terminal Location por identidad comercial;
- ConnectionToken efímero y scoped;
- venta presencial trazable;
- PaymentIntent `card_present` como Direct Charge;
- Stripe Checkout para fallback web;
- estados created/processing/succeeded/failed/refunded/disputed;
- webhook v267;
- trazabilidad con source kind / reference id;
- RLS deny-by-default en las nuevas tablas.

## Seguridad

- No se incluye ninguna Stripe secret key en frontend, Android o iOS.
- No se almacenan datos brutos de tarjeta.
- ConnectionToken y PaymentIntent se generan en backend.
- El cliente nativo no decide cuenta conectada, destinatario ni importe de forma unilateral: usa el contrato autorizado por backend.
- QR se genera dentro de KOMBAX; no se transmite la URL de Checkout a generadores QR externos.
- Las tablas Terminal R81 no ofrecen acceso directo a authenticated/anon; se accede mediante RPC/Edge Function controlados.
- No se incluyen JKS/keystore, `.env` reales, certificados Apple, `.p12` ni provisioning profiles.

## UX premium

El Payment Center presenta Tarjeta, SEPA y Tap to Pay como tarjetas diferenciadas, con estado y acciones. El modal de cobro presencial incluye importe, concepto, contexto de venta, compatibilidad y fallback. El comportamiento cambia automáticamente según Android nativo, iOS nativo o web/Safari.

## Internacionalización

La nueva experiencia mantiene los ocho idiomas activos: ES, EN, FR, PT, IT, DE, TH y FIL.

## Compatibilidad / requisitos externos

Android Tap to Pay real requiere dispositivo compatible, Android 13+, NFC, hardware-backed keystore soportado por Stripe y un entorno de producción seguro. La APK/AAB final debe firmarse localmente.

iOS Tap to Pay real requiere Apple Developer, entitlement de Tap to Pay on iPhone aprobado por Apple, Xcode y firma/provisioning. El código fuente se entrega preparado; la autorización de Apple no puede incluirse en un ZIP.

## Backend live

La migración R81 y las Edge Functions `stripe-terminal`, `stripe-webhook` y `health` se han aplicado/desplegado en el Supabase actual de KOMBAX. No se efectuó ningún cargo real durante esta fase.

## Release

- Release: R81
- Build: 20133
- Base anterior: R80 build 20132
- Nueva base acumulativa: R81 build 20133

## Certificación de cierre

El comando exacto de release configurado en Netlify (`npm run release:build`) se ejecutó sobre esta base y finalizó PASS, incluyendo legal gate, regresión acumulativa y build. El resultado final de sincronización es **466 archivos con igualdad exacta entre `web`, `dist` y los assets Android**.

El preflight Android quedó 4/5 únicamente porque `android/keystore.properties` es una credencial/configuración privada de firma local y se excluye deliberadamente del paquete. La fuente iOS pasó validación sintáctica (`swiftc -parse`); la compilación y firma iOS final requieren macOS/Xcode y entitlement Apple.
