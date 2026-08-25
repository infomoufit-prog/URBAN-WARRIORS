KOMBAX RC13 build 20080 · FINANCE PREMIUM DASHBOARD
25/08/2026

Base: release/kombax-20078-product-overview + Finance V2 foundation 143.

Este paquete es acumulativo para Finanzas Premium: incluye la migración 143 corregida para conservar el backend_version RC13 exacto, la nueva migración 144, el worker recurrente y la capa web Premium.

20080 añade:
- Dashboard Premium feature-flagged con fallback automático a Finanzas RC13.
- Navegación: Resumen / Cargos / Automatizaciones / Pagos / Recibos / Informes.
- KPI interactivos y cross-filtering.
- Barras mensuales Generado/Cobrado/Pendiente con drill-down por serie y mes.
- Antigüedad de deuda interactiva.
- Tabla desktop + cards móvil + detalle de cargo.
- + Nuevo cargo en 8 pasos con preview server-side obligatorio.
- Cargos masivos auditados y eventos agrupados en el sistema de notificaciones existente.
- Automatizaciones con alta, pausa/activación explícita y simulación shadow.
- Pagos por validar y recibos usando el mismo dataset filtrado del dashboard.
- Exportación CSV de la página filtrada como apoyo; el PDF histórico Premium queda para la siguiente capa.

SEGURIDAD / ROLLOUT
- No aplicar 143 y activar flags antes de aplicar también 144.
- Los cuatro flags permanecen false por defecto.
- finance_recurring_enabled debe continuar false en el piloto inicial.
- El worker recurrente continúa en shadow por defecto.
- No hay cambios destructivos sobre pagos/recibos históricos.

QA:
  node scripts/test-kombax-20079-finance-premium-foundation.mjs
  node scripts/test-kombax-20080-finance-premium.mjs .

Consulta docs/FINANCE_PREMIUM_V2_20080_ROLLOUT.md antes de activar flags.
