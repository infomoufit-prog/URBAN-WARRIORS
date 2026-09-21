# KOMBAX R61 · Auditoría e implementación de pagos

## Base auditada

- Frontend: SPA JavaScript sin framework en `web/`, compilada por `scripts/build.mjs` hacia `dist/`.
- Backend: Supabase/Postgres con gateway RPC, RLS, Storage y Edge Functions Deno.
- Identidad: Supabase Auth; perfiles multiclub y perfiles directos, con aislamiento de contexto reforzado en R60.
- Roles de club: Dirección, Secretaría, Economía, Comunicación, Monitor, Familia y Alumno; Coordinación se modela como capacidad adicional.
- Finanzas: `cuotas`, `pagos`, `recibos_cuota`, vistas de cuenta y Finance Premium V2 con generación recurrente protegida por gates y QA.
- Showcase: fichas, galería, guardados, comentarios/contacto y proveedores Club/Marca/otros; se amplía sin sustituirlo.
- Assist: conversación de gestión con contexto autorizado, reserva de uso y Edge Function separada.
- Android: contenedor WebView/PWA con FCM; no existe SDK nativo de pagos o Terminal.
- Infraestructura previa de pagos: registro manual y recurrencia contable, pero no procesador de tarjeta ni Connect.

## Decisión Stripe Connect corregida en R62

KOMBAX opera como software SaaS para clubes y vendedores independientes. Cada pago usa un **cargo directo** creado en la cuenta conectada mediante la cabecera `Stripe-Account`. Stripe fija y cobra sus tarifas directamente al club o vendedor, asume la responsabilidad del saldo negativo y recopila sus requisitos. La cuenta dispone del panel Stripe completo. KOMBAX no recibe el principal, no ejecuta transferencias y no aplica comisiones por transacción.

Configuración inmutable al crear la cuenta: `controller.fees.payer=account`, `controller.losses.payments=stripe`, `controller.requirement_collection=stripe` y `controller.stripe_dashboard.type=full`. Las cuentas R61 incompatibles se bloquean y requieren recreación expresa; nunca se reutilizan silenciosamente.

Las suscripciones de software KOMBAX (Club, Club Pro, Marca y otros planes) quedan separadas lógica y operativamente en Stripe Billing, con secretos, webhooks, tablas y conciliación distintos de Connect.

Referencias: https://docs.stripe.com/connect/charges y https://docs.stripe.com/connect/accounts-v2/connected-account-configuration.

## Implementado

- Estado y onboarding Connect para Club y proveedor Showcase.
- Checkout alojado de Stripe para cuotas y productos, compatible con métodos habilitados por Stripe para la cuenta/país.
- Firma HMAC, tolerancia temporal, idempotencia y ledger de webhooks.
- Estados de pago, referencia Stripe, fecha y fallo sobre la cuota existente.
- Entitlements comerciales configurables por plan.
- Precio, stock, variantes y entrega sobre las fichas Showcase existentes.
- Pedidos, historial, seguimiento e incidencias con separación comprador/vendedor.
- Comisión de plataforma por transacción bloqueada en base de datos y Edge Function.
- KOMBAX Assist reconoce la activación de cobros y solo abre Stripe tras confirmación visible.

## Deuda y límites conscientes

- La migración 259 y las funciones iniciales se aplicaron al proyecto autorizado; R62 corrige el modelo de fondos antes de configurar secretos Stripe.
- Los cobros automáticos off-session quedan preparados mediante autorizaciones, pero no se activan en R61. Hace falta cerrar consentimiento, notificaciones y política de reintentos con asesoría operativa/legal.
- No hay carrito multivendedor. Cada checkout corresponde a un vendedor.
- Las estadísticas/promociones están habilitadas como entitlement, no se construye todavía un BI comercial completo.
- La migración debe probarse en una rama/local Supabase con el histórico real antes del piloto.

## Orden de activación

1. Aplicar la migración R62 y ejecutar su verificación.
2. Configurar exclusivamente los secretos Connect de `PAYMENTS_R61_ENV.example`.
3. Desplegar `stripe-connect`, `stripe-checkout` y `stripe-webhook`.
4. Registrar en Stripe el endpoint público de `stripe-webhook` para eventos de cuentas conectadas.
5. Completar onboarding de un club y un vendedor de prueba.
6. Probar pago, fallo, reembolso, duplicado de webhook y aislamiento con dos clubes.
7. Solo tras QA, habilitar vendedores reales.
