# KOMBAX R62.4 — Stripe Connect QA / Hardening

Fecha de preparación: 10/09/2026
Base: `KOMBAX_20110_R62_3_STRIPE_CONNECT_TEST_READY.zip`

## 1. Objetivo

R62.4 endurece la integración Stripe Connect existente sin cambiar el modelo económico de KOMBAX. Mantiene **Direct Charges** sobre la cuenta conectada y extiende Connect a tres tipos de entidad económica independientes:

- **Club** (`subject_type=club`)
- **Marca / proveedor Showcase** (`subject_type=showcase_provider`)
- **Federación** (`subject_type=federation`)

La cuenta Stripe se asocia a la entidad, no al usuario que la administra. Un mismo usuario puede administrar varias identidades y cada organización conserva su propio `acct_...`.

## 2. Modelo económico preservado

Flujo de cobro:

`cliente/alumno/comprador → Stripe Connected Account de la entidad`

KOMBAX no usa `application_fee_amount`, `transfer_data.destination` ni `on_behalf_of`. El Checkout se crea con el contexto de la Connected Account y la base de datos mantiene `platform_fee_minor = 0`.

Para Accounts v2, la creación solicita:

- `fees_collector = stripe`
- `losses_collector = stripe`
- dashboard completo
- configuración Merchant con card payments

Stripe Billing para las suscripciones SaaS de KOMBAX debe seguir separado de Stripe Connect.

## 3. Cambios realizados en R62.4

### Accounts v2

- Se centralizó el cliente Accounts v2 en `_shared/stripe.ts`.
- Versión por defecto: `2026-07-29.dahlia`.
- Puede sobrescribirse mediante `STRIPE_CONNECT_API_VERSION` para una actualización controlada.
- Se eliminó la dependencia de la cabecera `.preview` anterior.
- No se envía `requirements_collector` en la creación porque no es un parámetro de creación; Stripe lo expone en la respuesta de la configuración correspondiente.
- Se normaliza el estado real de Merchant card payments, payouts y requirements sin almacenar datos KYC sensibles.

### Estado sincronizado

`stripe-connect` ya no depende únicamente del snapshot almacenado. La acción `status`:

1. autentica al usuario;
2. resuelve server-side la Connected Account autorizada;
3. consulta el Account v2 actual en Stripe;
4. normaliza estado/capabilities/requirements;
5. sincroniza el snapshot mínimo en Supabase;
6. devuelve únicamente el estado seguro al frontend.

### Idempotencia

- Creación de Connected Account: `Idempotency-Key` estable por entidad.
- Creación de Checkout: `Idempotency-Key` estable por intento interno.
- Un `request_id` de Checkout existente devuelve de nuevo todo el contexto server-side necesario para reutilizar correctamente la sesión.
- Se impide reutilizar un mismo `request_id` para otro concepto/referencia.

### Protección de asociación

La RPC interna de attach ahora vuelve a autorizar la entidad y no permite sustituir silenciosamente un `stripe_account_id` ya asociado. Si existe otro `acct_...`, devuelve `CONNECTED_ACCOUNT_REASSIGNMENT_FORBIDDEN`.

### Return / refresh de onboarding

Los Account Links incluyen el tipo e ID de la entidad en `return_url` y `refresh_url`.

- `payments=refresh`: KOMBAX restaura sesión y solicita un nuevo Account Link autenticado.
- `payments=return`: KOMBAX fuerza una sincronización real de Stripe antes de mostrar el estado.

`KOMBAX_APP_URL` se valida. HTTPS es obligatorio excepto en hosts locales (`localhost`, `127.0.0.1`, `::1`) para QA.

## 4. Permisos por entidad

### Club

Se conserva el modelo existente. La gestión de onboarding continúa restringida a Dirección/gestión autorizada. Los roles financieros permitidos pueden consultar estado según las RPC existentes.

### Marca / Showcase

Se conserva la política existente de gestión del proveedor Showcase. El panel de Marca consulta estado Connect y permite activar/revisar cobros al gestor autorizado.

### Federación

R62.4 añade Connect sobre el `perfil_directo` de tipo `federacion`.

**Consulta de estado**: propietario del perfil, gestores activos del perfil, equipo federativo con capacidad financiera (`federation.team.finance`) y administrador de plataforma.

**Alta/onboarding/attach**: propietario del perfil directo, gestor `owner/admin`, rol federativo `presidencia` y administrador de plataforma.

Tesorería puede consultar el estado financiero, pero no puede reemplazar/crear una Connected Account por sí sola. La Federación debe estar activa y verificada.

## 5. Aislamiento multientidad

La migración añade `federation_profile_id` y conserva unicidad global de `stripe_account_id` y unicidad `(subject_type, subject_id)`.

Mapeo válido:

- `club` → `club_id = subject_id`
- `showcase_provider` → `showcase_provider_id = subject_id`
- `federation` → `federation_profile_id = subject_id`

Los demás campos de entidad deben ser `NULL`. Esto evita que una misma fila represente más de una organización.

## 6. Checkout disponible en esta base

### Club — LISTO PARA QA DE PAGO

Concepto implementado: `club_fee`.

El importe, moneda, beneficiario y Connected Account se resuelven server-side desde la base de datos. No se confía en el `amount` ni en el `stripe_account_id` del navegador.

### Marca — LISTO PARA QA DE PAGO

Concepto implementado: `showcase_order`.

El producto, cantidad, importe y proveedor se resuelven server-side. El Checkout se crea sobre la cuenta conectada de la Marca/proveedor correspondiente.

### Federación — ONBOARDING/STATUS LISTO; CHECKOUT DE COBRO FEDERATIVO PENDIENTE

La R62.3 no incluye un `kind` de Checkout federativo ni una tabla/entidad de deuda federativa con importe server-side que pueda utilizarse de forma segura como fuente de verdad.

R62.4 **no inventa importes ni acepta un importe enviado por frontend**. Por tanto:

- la Federación puede activar y sincronizar Stripe Connect;
- puede quedar preparada para cobrar;
- todavía no se puede certificar un pago de licencia/inscripción federativa hasta que exista un concepto de cobro federativo server-side (por ejemplo, una deuda/licencia/tarifa con importe y moneda persistidos y autorizados).

Ese flujo debe implementarse en una versión posterior antes de declarar `FEDERATION PAYMENT VERIFIED`.

## 7. Webhook para piloto

R62.4 conserva el webhook firmado de eventos snapshot compatible con el flujo actual. Para el piloto no se mezclan Thin Events v2 con este endpoint.

Eventos Connected Accounts requeridos por la lógica actual:

- `account.updated`
- `checkout.session.completed`
- `payment_intent.succeeded`
- `payment_intent.payment_failed`
- `charge.refunded`
- `charge.dispute.created`

El endpoint verifica firma HMAC y tolerancia temporal antes de aplicar el evento. La aplicación usa además la lectura explícita Accounts v2 durante `status`/retorno del onboarding para mantener el estado actualizado.

Si en el futuro se adoptan eventos `v2.core.account...` thin, deben ir a un handler diseñado para thin events: validar evento, recuperar el Account v2 completo y luego sincronizar. No tratar un thin event como un snapshot completo.

## 8. Variables de entorno

Connect:

```env
STRIPE_CONNECT_SECRET_KEY=sk_test_...
STRIPE_CONNECT_WEBHOOK_SECRET=whsec_...
STRIPE_CONNECT_API_VERSION=2026-07-29.dahlia
KOMBAX_APP_URL=http://127.0.0.1:4173
```

Producción:

```env
KOMBAX_APP_URL=https://kombax.es
```

Billing, si está activo, debe usar secretos independientes:

```env
STRIPE_BILLING_SECRET_KEY=...
STRIPE_BILLING_WEBHOOK_SECRET=...
```

No poner secretos Stripe en `web/`, `dist/`, Android assets ni `config.js`.

## 9. Preparación del entorno Stripe TEST

Antes del QA end-to-end:

1. Aplicar en un proyecto Supabase de TEST las migraciones pendientes, incluida `20260910175619_kombax_stripe_connect_hardening_federation_r62_4.sql`.
2. Ejecutar `supabase/verification/verify_r62_4_stripe_connect.sql`.
3. Configurar los secretos Connect en Supabase Edge Functions.
4. Desplegar en TEST:
   - `stripe-connect`
   - `stripe-checkout`
   - `stripe-webhook`
5. En Stripe Test Mode crear/configurar el webhook como **Connected accounts** apuntando a `stripe-webhook`.
6. Activar únicamente los eventos que realmente utiliza el handler.
7. Mantener separado cualquier webhook de Stripe Billing de KOMBAX.

Esta entrega NO realiza esos despliegues ni modifica producción.

## 10. QA local

Desde la raíz del proyecto:

```bash
npm install
npm run test:20110:r62.4
npm run build
npm run dev
```

Abrir:

`http://127.0.0.1:4173`

Arquitectura prevista:

`Frontend local → Supabase TEST remoto → Edge Functions TEST → Stripe TEST MODE`

Para el flujo normal no es necesario ejecutar Stripe en el PC si el webhook está desplegado en Supabase TEST. Si se decide probar un webhook puramente local, utilizar Stripe CLI o un túnel HTTPS según la documentación oficial de Stripe.

Si el Dashboard/Account Link de vuestra configuración concreta rechazase un callback HTTP local, utilizar un túnel HTTPS o mantener temporalmente un callback HTTPS de QA. No rebajar validaciones de producción para resolverlo.

## 11. Casos manuales

### Club

1. Entrar como Dirección de Urban Warriors.
2. Finanzas → Activar cobros con tarjeta.
3. Completar onboarding Stripe TEST.
4. Regresar a KOMBAX y comprobar estado sincronizado.
5. Crear/usar una cuota TEST pequeña.
6. Entrar como alumno elegible.
7. Pagar con un método de prueba oficial de Stripe.
8. Confirmar en KOMBAX: cuota pagada, PaymentIntent registrado, `platform_fee_minor=0`.

### Marca

1. Entrar como gestor de Marca.
2. Activar/revisar Connect.
3. Completar onboarding TEST.
4. Comprar un producto Showcase de prueba.
5. Confirmar pedido pagado y que el PaymentIntent pertenece a la Connected Account de la Marca.

### Federación

1. Entrar como Presidencia/propietario autorizado.
2. Activar Connect.
3. Completar onboarding TEST.
4. Confirmar sincronización y estado de capacidades.
5. No ejecutar todavía una licencia pagada como si estuviera soportada: falta el concepto federativo de cobro server-side.

## 12. Casos negativos prioritarios

- usuario no autorizado intenta iniciar onboarding;
- cuenta restringida / `charges_enabled=false`;
- doble clic / reintento de red;
- `request_id` reutilizado para otro concepto;
- intento de usar una Connected Account de otra entidad;
- webhook repetido;
- Checkout cancelado;
- tarjeta rechazada;
- refund;
- dispute;
- dos Clubes, dos Marcas y dos Federaciones con cuentas independientes.

## 13. Estado de validación al entregar este ZIP

| Hito | Estado |
|---|---|
| CODE READY | Sí, sujeto a build/QA incluido en el ZIP |
| LOCAL TEST READY | Sí, sujeto a build/QA incluido en el ZIP |
| STRIPE TEST ENVIRONMENT READY | Pendiente de aplicar migración/secrets/functions/webhook en entorno TEST |
| CLUB CONNECT ONBOARDING VERIFIED | Pendiente de prueba real Stripe TEST |
| BRAND CONNECT ONBOARDING VERIFIED | Pendiente de prueba real Stripe TEST |
| FEDERATION CONNECT ONBOARDING VERIFIED | Pendiente de prueba real Stripe TEST |
| CLUB PAYMENT VERIFIED | Pendiente de prueba real Stripe TEST |
| BRAND PAYMENT VERIFIED | Pendiente de prueba real Stripe TEST |
| FEDERATION PAYMENT VERIFIED | No; falta concepto federativo de Checkout server-side |
| REFUND VERIFIED | Pendiente de prueba real Stripe TEST |
| MULTITENANT STATIC/DB DESIGN | Implementado y verificable por SQL/QA |
| MULTITENANT END-TO-END | Pendiente de prueba Stripe TEST con varias entidades |
| PILOT READY | No hasta cerrar QA real de Stripe TEST |

## 14. Criterio de salida a piloto

No declarar `PILOT READY` hasta completar al menos:

- onboarding TEST real de Club y Marca;
- onboarding TEST de Federación;
- pago aprobado y rechazado para Club y Marca;
- webhook e idempotencia;
- refund;
- aislamiento con dos entidades distintas;
- cierre o decisión explícita sobre el concepto de cobro federativo.
