# KOMBAX 20.110 R62.8 — Pilot / QA handoff

## Recorridos prioritarios
1. Cuenta compradora → Showcase → **Mis pedidos** → revisar estados y tracking.
2. Vendedor aprobado → pedido confirmado → Preparando → Enviado + tracking → Entregado.
3. Servicio profesional → ficha visible/contactable → confirmar ausencia de botón de compra.
4. Vendedor → **Estadísticas** → validar inventario, tipos, stock y vendidos/no vendidos.
5. Organizador → Events → publicación sin ticketing.
6. Organizador → solicitar **Events + Ticketing** → Owner activa → aceptar contratos → conectar Stripe → habilitar ticketing.
7. Intentar checkout de ticket sin cualquiera de los gates: debe bloquearse en servidor.
8. Revisar Condiciones, Privacidad y Child Safety: operador `KOMBAX SPAIN`, sin datos personales anteriores.

## Distribución
- PWA/PC: contenido de `dist/` generado por `npm run build`.
- Android: proyecto completo en `android/`; el APK piloto se guarda en `artifacts/` cuando el entorno dispone de toolchain Android.
- Google Play: el repositorio conserva la configuración de release, pero la firma de producción requiere el keystore privado externo; nunca debe incluirse en GitHub/ZIP.
- Supabase: migraciones y Edge Functions incluidas en `supabase/`.

## Bloqueos antes de lanzamiento comercial público
- revisión jurídica profesional de contratos/políticas QA;
- completar datos fiscales, registrales y domicilio legal definitivo de KOMBAX SPAIN;
- QA autenticada con comprador, vendedor y organizador reales de piloto;
- prueba Stripe TEST completa de compra/reembolso y venta de ticket;
- firma release/AAB con credenciales privadas de Google Play.
