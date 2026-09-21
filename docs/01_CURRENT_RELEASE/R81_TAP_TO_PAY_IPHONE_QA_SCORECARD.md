# KOMBAX R81 build 20133 · QA Scorecard

| Gate | Resultado |
|---|---|
| Release identity R81 / 20133 | PASS |
| Stripe Connect preserved | PASS |
| Card online preserved | PASS |
| SEPA preserved | PASS |
| Terminal Location / ConnectionToken | PASS |
| Direct Charge `card_present` contract | PASS |
| Web QR / Checkout fallback | PASS |
| No external QR URL leakage | PASS |
| Webhook v267 reconciliation | PASS |
| RLS Terminal tables | PASS |
| Club / Federation / Brand / Event Organizer scope | PASS |
| Android native bridge | PASS · static/API contract |
| Android secure-device compatibility gate | PASS |
| iOS WKWebView bridge | PASS · source/static |
| Apple Tap to Pay entitlement declaration | PASS · source |
| 8-language R81 copy | PASS |
| R81 contract test | 40/40 PASS |
| Full cumulative `npm test` | PASS |
| R79 strict i18n audit | 0 unresolved |
| 8-language direct catalog | 1437/1437 each |
| Runtime copy audit | 4663/4663 · 0 unresolved |
| Web/dist/Android parity | PASS after release build |
| Supabase migration live | PASS |
| `stripe-terminal` live | ACTIVE · JWT required |
| `stripe-webhook` v267 path live | ACTIVE |
| Health build 20133 live | ACTIVE |
| Secret/signing scan | PASS before packaging |
| PDF guide preflight | PASS · 14 pages |

## Notas de plataforma

### Android

El código nativo se contrastó con la API oficial Stripe Terminal 5.8.x. En este entorno no se puede realizar un build Gradle final porque la red del contenedor bloquea la descarga de dependencias/Gradle. La compilación APK/AAB y firma final debe ejecutarse en Android Studio en el ordenador de desarrollo.

### iOS

El contenedor no es macOS/Xcode; por tanto, el proyecto iOS se entrega como fuente preparado y auditado estáticamente. La compilación, firma y solicitud/uso del entitlement Tap to Pay on iPhone se completa en Xcode con la cuenta Apple Developer de KOMBAX.

### Pagos

No se realizaron cargos live ni movimientos de dinero durante la implementación y validación.

## Certificación final de empaquetado

- Exact Netlify command `npm run release:build`: **PASS**.
- Final build parity: **466 files · web = dist = Android**.
- Android preflight: **4/5**, únicamente falta `android/keystore.properties`, excluido por seguridad.
- iOS Swift syntax parse: **PASS** con Swift 6.2.1; build firmado requiere Xcode/macOS.
- Secret/signing scan: **PASS**.
- PDF guide: **14/14 pages rendered and visually reviewed**.
