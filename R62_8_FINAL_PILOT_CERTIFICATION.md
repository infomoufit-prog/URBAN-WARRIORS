# KOMBAX 20.110 R62.8 — Certificación de entrega piloto / QA

## Identidad de release
- Build: **20110**
- Android versionCode: **20110**
- Android versionName: **2.0.0-rc.13-r62.8-pilot**
- Operador mostrado en legal/comercial: **KOMBAX SPAIN**

## Incluido
- código fuente completo y estructura histórica del repositorio;
- `web/` + `dist/` PWA/PC;
- Android completo con assets web sincronizados;
- Supabase migrations + Edge Functions;
- Showcase Marketplace: productos transaccionables y servicios profesionales no transaccionables;
- Mis pedidos para compradores autenticados;
- estados de fulfillment gestionados por vendedor con trazabilidad;
- Seller Center + Seller Dashboard/stock/ventas/GMV;
- Events base + add-on Events + Ticketing;
- contratos versionados de organizador/ticketing;
- Owner commercial review / verificaciones / analytics;
- legal público sin los datos personales anteriores y con KOMBAX SPAIN;
- PWA piloto empaquetada dentro de `artifacts/`.

## Verificaciones
- QA específica R62.8: PASS.
- Regresión completa del repositorio: PASS / exit 0.
- Build estática: PASS; `web = dist = Android assets`.
- Stripe Checkout Edge Function remoto: desplegado con JWT obligatorio y gates Showcase/Events.
- Supabase R62.8: 0 activaciones sintéticas de vendedores o ticketing.
- Escaneo de secretos: consultar `artifacts/R62_8_SECRET_SCAN.txt`.

## Android
El proyecto Android queda listo en código y assets, pero **este entorno no puede generar un APK/AAB nuevo**: Gradle 8.11.1 no está cacheado y el contenedor no tiene red para descargarlo. La firma release privada tampoco se incluye en el repositorio/ZIP. Consultar `artifacts/R62_8_ANDROID_BUILD_STATUS.md`.

Esto no debe confundirse con un fallo de la aplicación: el build se detiene antes de compilar por disponibilidad de toolchain. En el entorno Android habitual se mantienen los scripts `npm run android:debug:qa` y `npm run android:aab:play`.

## Antes de publicación comercial / Google Play
- completar datos fiscales/registrales/domicilio legal definitivo de KOMBAX SPAIN;
- revisión jurídica profesional de políticas/contratos QA;
- Stripe TEST end-to-end con comprador, vendedor y organizador reales;
- firma release/AAB con el keystore privado habitual;
- QA manual autenticada en PWA y Android.
