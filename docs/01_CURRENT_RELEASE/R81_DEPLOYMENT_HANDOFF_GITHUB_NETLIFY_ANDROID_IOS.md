# R81 build 20133 · Handoff GitHub / Netlify / Android / iOS

## 1. GitHub

Usa este paquete R81 como nueva base del repositorio. Antes de push:

```bash
npm test
node scripts/build.mjs
git status
```

No añadir a Git:

- `.env` reales
- `android/keystore.properties`
- `*.jks`, `*.keystore`
- `*.p12`, `*.mobileprovision`
- claves privadas/certificados de firma
- Stripe secret keys

## 2. Netlify

La configuración está en `netlify.toml` y publica `dist/`.

Secuencia:

```bash
npm test
node scripts/build.mjs
```

Después hacer push al repositorio conectado o despliegue del proyecto Netlify correcto de KOMBAX. Comprobar que las variables públicas/entorno productivo sigan siendo las del entorno actual y no sustituir secretos backend por valores del ZIP.

## 3. Android APK/AAB

Abrir la carpeta `android/` en Android Studio.

1. Restaurar localmente `android/keystore.properties`.
2. Sync Gradle.
3. Compilar en dispositivo físico compatible.
4. Para Tap to Pay real: Android 13+, NFC, hardware-backed keystore compatible, Internet, ubicación y entorno seguro sin debugging/opciones de desarrollador.
5. Ejecutar el flujo Stripe TEST antes de live.
6. Generar APK/AAB firmado.

La firma privada no se incluye en el ZIP.

## 4. iOS

Desde macOS:

```bash
cd ios
xcodegen generate
```

Después:

1. abrir el proyecto generado en Xcode;
2. seleccionar Team/Bundle ID definitivos;
3. resolver Stripe Terminal desde Swift Package Manager;
4. solicitar/activar entitlement `com.apple.developer.proximity-reader.payment.acceptance` con Apple;
5. firmar para dispositivo/TestFlight/App Store;
6. probar Tap to Pay on iPhone en Stripe TEST.

Mientras la app iOS no esté distribuida, Safari/PWA usa QR/enlace de pago desde el Payment Center.

## 5. Supabase

El backend R81 ya está aplicado en el entorno Supabase actual. La migración `270_kombax_terminal_tap_to_pay_r81.sql` se conserva para reproducibilidad y nuevos entornos.

No ejecutar DDL manual duplicado en producción si la migración ya consta aplicada.

## 6. Smoke test recomendado antes de mostrar/cobrar

- Login y navegación general.
- Finanzas / Payments Center premium.
- Tarjeta online visible/estado correcto.
- SEPA visible/estado correcto.
- Tap to Pay visible/estado correcto.
- Android físico: compatibilidad + Location + conexión Terminal en Stripe TEST.
- iPhone Safari: QR/enlace y Checkout TEST.
- Webhook: succeeded/failed/refund/dispute de prueba.
- Comprobar conciliación en KOMBAX.

No pasar a cargos live hasta cerrar el smoke Stripe TEST de cada flujo.
