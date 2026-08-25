# KOMBAX Finance Premium 2.0 · cierre 20083

20083 mantiene íntegramente 143–146 y añade una última barrera para la recurrencia real.

## Gate final

Nuevo flag por club, inicialmente `false`:

`finance_pilot_live_enabled`

Una ejecución `shadow=false` necesita simultáneamente:

1. `finance_recurring_enabled = true`
2. `finance_qa_shadow_approved = true`
3. `finance_pilot_live_enabled = true`

Además, la activación auditada `finance.pilot.activar` exige:

- Dirección o sesión Owner/support válida;
- QA sin anomalías bloqueantes;
- QA aprobado;
- dos Shadow OK consecutivos, misma fecha y fingerprint;
- al menos una regla activa;
- `finance_v2_enabled`;
- `finance_dashboard_v2_enabled`;
- confirmación literal `ACTIVAR RECURRENCIA`;
- `request_id` idempotente.

La UI 20083 **no expone un botón de activación real**. Solo muestra CLOSED / READY / LIVE. La apertura se hará en el piloto mediante el flujo auditado cuando todas las validaciones E2E hayan finalizado.

## Auto-cierre

Si `finance_qa_shadow_approved` pasa a `false` por revocación o por modificar reglas/destinatarios/excepciones, el trigger 148 fuerza también:

- `finance_pilot_live_enabled = false`
- `finance_recurring_enabled = false`

Por tanto un cambio de configuración después del QA no puede dejar una recurrencia real abierta.

## Históricos

148 no actualiza ni elimina:

- `pagos`
- `recibos_cuota`
- cargos históricos existentes

El cierre sigue siendo por flags y wrappers del motor.
