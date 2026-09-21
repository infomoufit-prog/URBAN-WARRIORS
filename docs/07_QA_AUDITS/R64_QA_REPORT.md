# KOMBAX 20.112 R64 - QA

## QA específico R64
`node scripts/test-kombax-20112-r64-commercial-pricing.mjs`

Resultado: **22/22 PASS**.

Cubre:
- identidad de build;
- pricing Club/Brand/Federation;
- Founder y anual;
- fees 1,5 % / 0 %;
- break-even;
- Commerce temporal y anticanibalización;
- publicación Events;
- Destacar unificado y frequency caps;
- eliminación comercial de Spotlight;
- Ticketing 1,50 € y QR/acceso incluidos;
- Gran Evento;
- taxonomía Profesional;
- 18+;
- protección Marca;
- Assist/Migrations;
- Partner;
- Plan y servicios + PDF;
- Social amplification;
- prioridad dinámica Showcase/Events;
- ausencia de copy antiguo de fee cero.

## Regresiones estables verificadas
- R58 Identity/Memberships/Media: PASS completo.
- R60 Assist/Migrations/Support/Conversations: 28/28 PASS.
- R60 navegación global Back/Close: 16/16 PASS.
- R62.6 Social Discovery: PASS completo.

## Tests históricos con aserciones ya superadas
Algunas baterías históricas no pueden considerarse criterio de R64 porque verifican decisiones comerciales eliminadas expresamente:
- R63 esperaba `platform_fee = 0` universal.
- R60 esperaba Migrations únicamente Club/Federación.
- R62.8 esperaba la nomenclatura visible `ADD-ON TICKETING`.
- R59 pasa sus 15 comprobaciones funcionales iniciales y falla el guard final de versión porque el test solo reconoce builds 20109/20110, no 20112.

No se han modificado esos tests históricos congelados para forzarlos a pasar.

## Build/paridad
- `node scripts/build.mjs`: OK.
- 203 archivos sincronizados.
- `web = dist = android/app/src/main/assets/www`.

## Android preflight
- Identidad Android: OK.
- versionCode 20112: OK.
- assets embebidos: OK.
- Firebase: OK.
- firma local/keystore: PENDIENTE.

Resultado: 4/5. No generar release definitiva hasta resolver firma local.

## PDF
- 7 páginas.
- PDF abrible y no cifrado.
- Render verificado sin recortes/solapes visibles.

## No ejecutado
- Migraciones R64 contra Supabase de producción.
- Cobros Stripe reales.
- APK/AAB release firmado.
- Deploy Netlify/Play/GitHub.
