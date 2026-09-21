# KOMBAX R65 · Commerce & Events Operations

**Build:** 20116  
**Base consolidada:** KOMBAX R64.4 / build 20115  
**Estado:** QA READY para estabilización/piloto; no se declara Production Ready hasta completar firma Android local, QA autenticada con usuarios reales y despliegues autorizados.

## 1. Objetivo cerrado

R65 completa la capa operativa profesional que faltaba sobre KOMBAX Showcase y KOMBAX Events sin reconstruir los módulos existentes. La versión añade control financiero, reembolsos parciales y totales, stock/reposición auditada, comunicaciones transaccionales, analítica comercial Enterprise, operaciones de asistentes y exposición del historial QR.

La fase de **KOMBAX SaaS Billing** —el cobro de las propias suscripciones/add-ons de KOMBAX— permanece intencionadamente fuera de R65. Stripe Connect para ventas de terceros sigue separado del futuro Billing de KOMBAX.

## 2. KOMBAX Showcase

R65 conserva Seller Center, catálogo, pedidos, stock, tracking, Stripe Connect y límites comerciales de R64.4 y añade:

- Finance Center para visualizar ventas, reembolsos, comisión KOMBAX retenida y contexto financiero de la cuenta Stripe conectada.
- Reembolso desde KOMBAX mediante Edge Function `stripe-refund`, con idempotencia y compatibilidad con direct charges.
- Reembolsos parciales sin forzar el pedido entero a estado `refunded`.
- Reposición de stock separada del movimiento financiero y registrada en ledger auditable.
- Cola de comunicaciones transaccionales para cambios comerciales y reembolsos, integrada con el outbox existente y el dispatcher de correo.
- Analítica Enterprise de impresiones, vistas, interés, checkout, compras, conversión, ingresos y top products.
- Superficie operacional del vendedor ampliada para finanzas, reembolsos, stock y comunicaciones.

## 3. KOMBAX Events

R65 conserva publicación, Ticketing, contratos, ventas, Wallet, QR, scanner y staff de acceso, y añade:

- Finance Center del evento con ventas y reembolsos.
- Reembolso individual de pedidos de entradas desde KOMBAX.
- Batches reanudables para cancelaciones/reembolsos masivos, limitados por lote para evitar procesos frágiles.
- Asociación exacta de tickets a cada reembolso parcial.
- Estado de reembolso incorporado a la proyección de ventas.
- Comunicaciones transaccionales a asistentes.
- Analítica Enterprise con vistas, checkout, compras, conversión, ingresos y check-ins reales.
- Historial QR/check-in visible para organizadores, apoyado en el audit existente.

## 4. Stripe y seguridad financiera

La arquitectura se mantiene en **Stripe Connect + direct charges**. R65 no utiliza `reverse_transfer`; cuando corresponde devuelve la application fee mediante el flujo de refund. El refund se prepara en PostgreSQL, se ejecuta contra Stripe desde una Edge Function autenticada y solo se finaliza como éxito cuando Stripe lo confirma.

Los ledgers privados R65 usan RLS y no conceden acceso directo a `anon` ni `authenticated`. Los RPC internos de refund/finanzas quedan restringidos a `service_role`. Las Edge Functions sensibles requieren JWT; `stripe-webhook` conserva autenticación por firma de Stripe.

## 5. Migraciones Supabase

El ZIP contiene exactamente las ocho migraciones R65 que figuran en el historial del proyecto conectado:

1. `20260913223620_kombax_r65_commerce_events_operations_part1.sql`
2. `20260913223644_kombax_r65_commerce_events_operations_part2.sql`
3. `20260913223707_kombax_r65_refund_prepare.sql`
4. `20260913223732_kombax_r65_refund_finalize_and_batches.sql`
5. `20260913223753_kombax_r65_sales_and_finance.sql`
6. `20260913223819_kombax_r65_bi_qr_order_operations.sql`
7. `20260913223837_kombax_r65_webhook_v265.sql`
8. `20260913223848_kombax_r65_outbox_hardening.sql`

La antigua migración consolidada se conserva solo como **referencia** en `supabase/migration_archive/` para no provocar drift ni reejecución futura con `db push`.

## 6. QA ejecutada

- Release regression R65: **21/21 PASS**.
- Operaciones Commerce & Events R65: **18/18 PASS**.
- Pre-batería crítica histórica incluida en `npm test`: **PASS**.
- Build determinista: **206 archivos; `web = dist = Android`**.
- Android preflight: **4/5**. Único pendiente: firma local (`android/keystore.properties`).
- El intento de APK debug no pudo finalizar porque el entorno de ejecución no tiene acceso de red a `services.gradle.org` para descargar Gradle 8.11.1. No es un fallo de compilación detectado en el código fuente.

Evidencias: `R65_FINAL_EVIDENCE/`.

## 7. Advisors Supabase

La revisión posterior mantiene avisos de performance históricos del proyecto (foreign keys sin índice, índices no utilizados y un índice duplicado histórico). Las nuevas tablas R65 también generan algunos avisos **INFO** de foreign keys sin índice; no son bloqueos de seguridad ni de funcionamiento para el piloto, pero conviene resolverlos en la siguiente fase de performance/escala antes de crecimiento intensivo.

No se ha eliminado ni alterado masivamente ningún índice histórico en esta entrega para evitar cambios de rendimiento no medidos justo antes del piloto.

## 8. Estado de despliegue

- **Supabase:** migraciones R65 presentes en el historial conectado; backend R65 sincronizado durante la implementación.
- **Frontend/Netlify:** no desplegado desde esta entrega.
- **GitHub:** no se ha realizado push.
- **Google Play:** no se ha publicado APK/AAB.
- **Android release firmada:** pendiente de ejecutarse localmente con el keystore del proyecto.

Esto respeta la política operativa del proyecto: los despliegues frontend/GitHub/Play requieren autorización explícita.

## 9. Siguiente fase separada

La siguiente fase funcional es **KOMBAX SaaS Billing**: productos/precios Stripe de KOMBAX, suscripciones, renovaciones, add-ons Commerce/Events/Ticketing/Destacar, facturación, estado de cobro, dunning y sincronización automática de entitlements. No se ha mezclado con R65 para mantener separado el dinero de compradores/vendedores (Connect) del dinero que KOMBAX cobra por el SaaS.

## 10. Criterio de salida a piloto

R65 puede usarse como nueva base de estabilización QA/piloto. Antes de declarar producción pública se recomienda completar: firma Android local, smoke test autenticado de reembolso real en Stripe test mode, prueba real de email transaccional, prueba multioperador QR y verificación visual móvil/desktop de los nuevos Finance Centers.
