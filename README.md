# KOMBAX R81 · build 20133

## EMPIEZA AQUÍ

Este paquete es la **base acumulativa completa y ordenada de KOMBAX R81 build 20133**. Sustituye a R80 build 20132 como única base válida para continuar desarrollo, generar APK/AAB, preparar iOS, subir a GitHub y desplegar el frontend en Netlify.

R81 conserva íntegramente R79/R80 —incluidos vídeo fullscreen, internacionalización, Stripe Connect, tarjeta y SEPA— y añade **Cobro presencial / Tap to Pay** como tercer método del KOMBAX Payments Center.

### Qué activa R81

- **Tarjeta online** mediante Stripe Connect.
- **Domiciliación bancaria SEPA** para flujos recurrentes/diferidos compatibles.
- **Tap to Pay en Android** mediante Stripe Terminal SDK nativo.
- **Tap to Pay on iPhone** mediante la nueva base iOS nativa, pendiente únicamente de firma/entitlement Apple para distribución real.
- **Fallback web para iPhone/Safari/PWA** mediante Stripe Checkout + QR/enlace de pago seguro mientras no exista app iOS distribuida.
- Una sola cuenta Stripe Connect por identidad comercial.
- Aplicación transversal a **Club, Federación, Marca/Showcase y Organizador de eventos** según permisos/servicio.
- Direct Charges: el dinero se procesa en la cuenta conectada de la identidad comercial; KOMBAX no custodia el importe.
- Conciliación por webhook para processing/succeeded/failed/refunded/disputed.
- 8 idiomas: ES, EN, FR, PT, IT, DE, TH y FIL.

## Estructura principal

| Carpeta / archivo | Qué contiene | Uso habitual |
|---|---|---|
| `web/` | Fuente del frontend/PWA: vistas, módulos, i18n, CSS premium y assets. | Desarrollo frontend |
| `dist/` | Build web generado para Netlify. Debe coincidir con `web/` tras `node scripts/build.mjs`. | Despliegue |
| `android/` | Proyecto Android, puente WebView y Stripe Terminal Tap to Pay. | APK/AAB |
| `ios/` | Variante iOS: SwiftUI/WKWebView, puente KOMBAX y Stripe Terminal Tap to Pay on iPhone. | Xcode/TestFlight/App Store |
| `supabase/` | Migraciones SQL, Edge Functions y configuración backend. | Backend |
| `scripts/` | Build, QA, auditoría, i18n, preflight y utilidades de release. | Validación |
| `docs/` | Documentación actual e histórica, guías, QA, legal y manifests. | Consulta/handoff |
| `qa/` | Evidencias QA históricas/estructuradas. | QA |
| `maintenance/` | Material de mantenimiento y handoff acumulado. | Operación |
| `load/` | Recursos de pruebas de carga. | QA de carga |
| `artifacts/` | Artefactos históricos preservados por trazabilidad. | Archivo |
| `package.json` | Scripts NPM de test/build/certificación. | Desarrollo |
| `netlify.toml` | Configuración activa de build, publish, redirects y headers de Netlify. | Despliegue |
| `PAYMENTS_R61_ENV.example` | Plantilla de referencia; no contiene secretos reales. | Configuración |

## Documentación R81

Empieza por `docs/00_INDEX_R81.md`.

Los documentos de release están en `docs/01_CURRENT_RELEASE/`:

- `R81_TAP_TO_PAY_IPHONE_FINAL_REPORT.md`
- `R81_TAP_TO_PAY_IPHONE_QA_SCORECARD.md`
- `R81_LIVE_SUPABASE_STATE.md`
- `R81_DEPLOYMENT_HANDOFF_GITHUB_NETLIFY_ANDROID_IOS.md`
- `GUIA_KOMBAX_COBROS_TAP_TO_PAY_IPHONE_R81.pdf`
- `R81_BUILD_20133_MANIFEST_SHA256.txt` (se genera en el cierre del paquete)

La guía también está integrada en la plataforma:

`web/assets/docs/GUIA_KOMBAX_COBROS_TAP_TO_PAY_IPHONE_R81.pdf`

## Frontend y experiencia premium

En el Payments Center el usuario ve tres métodos independientes:

1. **Cobros con tarjeta**
2. **Domiciliación bancaria SEPA**
3. **Cobro presencial · Tap to Pay**

El flujo presencial detecta el entorno:

- App Android compatible → Tap to Pay Android.
- Futura app iOS compatible → Tap to Pay on iPhone.
- Safari/PWA/web → QR + enlace Stripe Checkout.

No se envía la URL del pago a servicios QR externos: el QR se genera dentro de la integración KOMBAX.

## Backend live de esta release

La migración R81 Terminal/Tap to Pay ya fue aplicada al Supabase de KOMBAX y están desplegadas las funciones necesarias. Consulta `docs/01_CURRENT_RELEASE/R81_LIVE_SUPABASE_STATE.md` para el estado certificado.

La migración reproducible incluida en el ZIP es:

`supabase/migrations/270_kombax_terminal_tap_to_pay_r81.sql`

No vuelvas a ejecutarla manualmente contra un entorno donde ya figure aplicada; usa el flujo normal de migraciones del proyecto.

## Comandos de validación

Instalación, si es necesaria:

```bash
pnpm install
```

Regresión acumulativa completa:

```bash
npm test
```

Test contractual R81:

```bash
node scripts/test-kombax-20133-r81-tap-to-pay.mjs
```

Build determinista Web / dist / Android:

```bash
node scripts/build.mjs
```

Preflight Android:

```bash
npm run android:preflight
```

## Generar APK / AAB

Abre `android/` en Android Studio. La firma de release es local: `android/keystore.properties` **no se distribuye** en este paquete por seguridad. Una vez restaurada la configuración de firma en tu ordenador, sincroniza Gradle y genera APK/AAB firmado.

Stripe Terminal Android usa la rama 5.8.1 en esta release. Tap to Pay real requiere dispositivo físico compatible, Android 13+, NFC, hardware-backed keystore compatible y entorno seguro sin opciones de desarrollador/debug en producción.

## iPhone / iOS

Hasta que la app iOS esté publicada, los usuarios de iPhone pueden utilizar KOMBAX en Safari/PWA y cobrar presencialmente mediante **QR/enlace de pago**.

Para convertir el propio iPhone del negocio en terminal NFC se necesita la app nativa. El código fuente está en `ios/` y requiere:

- macOS + Xcode;
- Apple Developer;
- entitlement **Tap to Pay on iPhone** aprobado por Apple;
- firma y provisioning propios;
- resolución del paquete Stripe Terminal.

No se incluyen certificados, `.p12`, perfiles de provisioning ni secretos.

## Netlify

`netlify.toml` está preparado para publicar `dist/`. Antes de desplegar:

```bash
npm test
node scripts/build.mjs
```

Después sube el repositorio/ZIP al proyecto Netlify correcto de KOMBAX. Esta entrega no cambia credenciales ni enlaza un proyecto Netlify distinto automáticamente.

## GitHub

El paquete está preparado para convertirse en la nueva base del repositorio. No subas:

- `.env` reales;
- `android/keystore.properties`;
- JKS/keystores;
- certificados Apple;
- `.p12`;
- provisioning profiles;
- claves Stripe secretas.

La `.gitignore` y los controles de release mantienen estos elementos fuera de la entrega.

## Regla de continuidad

**R81 build 20133 pasa a ser la única base acumulativa válida.**

Para cualquier fase posterior:

1. partir de este paquete completo;
2. no reconstruir desde R80/R79;
3. mantener toda la funcionalidad acumulada;
4. ejecutar `npm test`;
5. ejecutar build determinista;
6. auditar secretos/firma;
7. crear un ZIP acumulativo nuevo con manifest y SHA-256.
