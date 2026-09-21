# KOMBAX 20.101 R31 · PLAN DE IMPLEMENTACIÓN
## PROFESSIONAL BASIC FINANCE

Estado inicial: PLAN PREVIO DE R31, creado antes de modificar código de esta revisión.
Base: R30 PROFESSIONAL RELATIONS & BASIC OPERATIONS cerrada y validada.

## 1. Objetivo
Implementar Finanzas Profesionales básicas como dominio propio por `professional_profile_id`, reutilizando patrones visuales/matemáticos cuando sean compatibles, sin convertir al Profesional en un Club ficticio ni modificar destructivamente Finanzas Club.

## 2. Alcance
- Capabilities `professional.finance.manage` y `professional.finance.reports`.
- Servicios/tarifas administrativas propias.
- Cargos profesionales.
- Pagos registrados administrativamente.
- Gastos.
- KPIs Generado/Cobrado/Pendiente/Gastos.
- Recordatorios derivados de cargos vencidos y no satisfechos.
- Relaciones opcionales con cliente propio, representado consentido o asignación propia de Events.
- RPC de lectura y mutación con idempotencia, auth, ownership y capability checks.
- RLS, GRANTs, auditoría y advisors.
- UI profesional específica, sin reescribir Finanzas Club.

## 3. Fuera de alcance
- Stripe, TPV, pasarela bancaria o procesamiento de dinero.
- Ticketing.
- Facturación fiscal.
- Impuestos/IVA/VeriFactu.
- Club ficticio o `club_id` en tablas financieras profesionales.
- Recurrencia automática de cargos en R31.
- Alteración destructiva de tablas `cuotas`, `pagos`, `reglas_cobro` o informes de Club.

## 4. Arquitectura
`Professional Finance UI -> Professional Finance adapter -> RPC v199 -> tablas profesionales v199`

Finanzas Club conservan sus tablas/RPC/UI actuales. Se comparte únicamente semántica compatible de KPIs, estados y formato, no el tenancy.

## 5. Backend previsto
- `kombax_professional_services_v199`
- `kombax_professional_charges_v199`
- `kombax_professional_payments_v199`
- `kombax_professional_expenses_v199`
- `kombax_professional_finance_audit_v199`
- `app_kombax_professional_finance_v199(uuid)`
- `app_kombax_professional_finance_mutate_v199(text,jsonb,uuid)`

## 6. Invariantes
- Todas las entidades privadas están aisladas por `professional_profile_id`.
- Cliente/servicio/asignación deben pertenecer al mismo profesional.
- `represented_profile_id` requiere delegación Manager→Competidor aceptada, vigente y no revocada.
- Estado de cargo se deriva de la suma de pagos; el frontend no decide `pagado`.
- No se admiten sobrepagos.
- Un cargo con pagos no se anula de forma destructiva.
- No existe `club_id` en el nuevo dominio financiero.
- `factura fiscal` no es un documento generado por R31.

## 7. Seguridad
- RLS habilitada en todas las tablas.
- Sin DML directo para `authenticated`; mutaciones por RPC.
- RPC SECURITY DEFINER con `search_path` fijo.
- Validación `auth.uid()`, perfil gestionable y capability sensible.
- IDs enviados por frontend siempre se revalidan contra el subject.
- Uso de `(select auth.uid())` en policies si fuese necesario para evitar `auth_rls_initplan`.

## 8. Frontend
- `web/js/core/finance-adapter.js`
- `web/js/modules/professional-finance.js`
- repositorios para snapshot y mutación.
- acceso desde Mi actividad solo con capability.
- KPIs y operaciones administrativas con terminología: Cargo, Pago registrado, Gasto, Comprobante interno/Informe.
- aviso permanente: KOMBAX registra actividad administrativa; no procesa dinero ni genera facturas fiscales.

## 9. QA
- Test dedicado R31.
- Aislamiento Profesional A/B estructural y live.
- No fake club / no `club_id`.
- Sin sobrepagos.
- Estado derivado backend.
- Manager solo con delegación aceptada vigente.
- Asignación/cliente/servicio cross-subject bloqueados.
- RLS/GRANTs/auth gates.
- Security Advisor + Performance Advisor y corrección de findings nuevos relevantes.
- Regresión completa R27-R31.
- Build/paridad web=dist=Android.
- Android preflight sin afirmar firma si falta `keystore.properties`.

## 10. Criterio de cierre
R31 solo cierra si Finanzas Profesionales quedan aisladas y funcionales, Finanzas Club mantienen su regresión histórica, no existe fake Club, los tests dedicados/globales pasan y el backend live queda verificado y documentado.
