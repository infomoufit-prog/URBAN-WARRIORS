# CHANGELOG — KOMBAX 20.110 R62.4

## Stripe Connect Hardening + Federation

- Accounts v2 actualizado de preview a `2026-07-29.dahlia` con override controlado por env.
- Cliente Stripe v2 centralizado en `_shared/stripe.ts`.
- Sincronización server-side del estado real de Connected Accounts.
- Normalización segura de card payments, payouts y requirements.
- Idempotencia añadida a creación de Connected Account y Stripe Checkout.
- Reintentos de Checkout conservan contexto server-side completo.
- Protección contra reutilización de `request_id` para otro concepto.
- Protección contra reasignación silenciosa de `stripe_account_id`.
- Account Link refresh/return reconstruido y autenticado desde KOMBAX.
- Validación de `KOMBAX_APP_URL` para producción/local QA.
- Connect extendido a Federación como entidad económica independiente.
- Permisos Federación alineados con perfil directo + roles/capacidades existentes.
- UI Federación: tarjeta de cobros Connect y activación para gestores autorizados.
- UI Marca: estado Connect visible y acción Activar/Revisar cobros.
- Verificación SQL R62.4 añadida.
- QA estático R62.4 añadido.
- Documentación de prueba local y Stripe TEST añadida.

### Fuera de alcance deliberadamente

- No se ha creado un concepto de cobro federativo ficticio. La base R62.3 no tiene todavía un `kind` de Checkout federativo con importe server-side; Federación queda Connect-ready/onboarding-ready, pero `FEDERATION PAYMENT VERIFIED` requiere implementar ese concepto de negocio.
- No se despliega Netlify.
- No se hace push a GitHub.
- No se modifican secretos ni producción.
