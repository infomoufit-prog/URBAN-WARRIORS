# KOMBAX 20.101 · R31 · Professional Basic Finance

## Estado
CERRADA sobre R30 validada.

## Implementación
- Finanzas Profesionales independientes por `professional_profile_id`; no se usa `club_id` ficticio.
- Capabilities `professional.finance.manage` y `professional.finance.reports`.
- Servicios profesionales, cargos, pagos registrados, gastos y auditoría.
- Estado de cargos derivado de pagos registrados: pendiente / parcial / pagado; anulado separado.
- Bloqueo de sobrepago y de reducción de cargo por debajo de pagos ya registrados.
- Cargos vinculables a cliente, servicio, asignación Events y, para Manager, representado con delegación aceptada y vigente.
- Sin procesamiento de dinero, pasarela bancaria ni facturación fiscal automática.
- Adapter financiero común con scope explícito `club` / `professional`.
- Integración en `Mi actividad` exclusivamente por capability.
- Informe básico de 12 meses: generado, cobrado registrado, pendiente, gastos y neto.
- Avisos financieros reutilizando la tabla global `notificaciones`, generalizada con `subject_type=direct_profile` y `subject_id`, sin crear un segundo centro de notificaciones.

## Backend vivo
- 202: `kombax_professional_finance_schema_20101_r31`.
- 203: `kombax_professional_finance_runtime_20101_r31`.
- 204: `kombax_professional_notifications_policy_hardening_20101_r31`.
- RLS activa y DML directo revocado para `anon` / `authenticated` en tablas financieras privadas.
- RPC públicos R31 disponibles únicamente a `authenticated`; `anon` no tiene EXECUTE.
- `search_path` fijado en los RPC SECURITY DEFINER.

## QA
- Test dedicado R31: 15/15 PASS.
- Regresión global R28-R31: PASS.
- Performance Advisor: warning nuevo de policies permisivas múltiples corregido en 204.
