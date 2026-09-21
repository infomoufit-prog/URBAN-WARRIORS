# KOMBAX RC13 build 20080 · Finanzas Premium 2.0

## Alcance

20080 continúa la Foundation 20079 sin sustituir Finanzas RC13. La pantalla RC13 se renderiza primero y un bootstrap aditivo solo la sustituye cuando el usuario pertenece al equipo financiero y están activos `finance_v2_enabled` y `finance_dashboard_v2_enabled`. Si falla el gate o el renderer Premium, se conserva/restaura la UI RC13.

## Backend incluido

La migración 143 del paquete 20080 está corregida para que cualquier nueva mutación Finance V2 conserve el `backend_version` autoritativo de `app_runtime_meta`. Esto es obligatorio porque el cliente RC13 exige coincidencia exacta con `1.6.0`.

La migración 144 añade:

- `app_finance_v2_dashboard_v144`: fuente única para KPI, gráfico, aging, tabla, pagos y recibos filtrados.
- `app_finance_v2_preview_cargo_v144`: preview obligatorio server-side para `+ Nuevo cargo`.
- `finance.cargo.crear` dentro del mismo `app_mutate_v160` idempotente.
- `lote_cargo_id` para trazabilidad de operaciones masivas.
- deduplicación de destinatarios que llegan por scopes solapados.
- eventos agrupados a alumno/familia y tesorería mediante `notificaciones`; no se crea otro sistema push.
- auditoría explícita de lotes manuales.

Los conceptos manuales guardan un sufijo técnico interno de lote para no colisionar con la restricción histórica `(club, alumno, periodo, concepto)`, mientras `concepto_publico` conserva exactamente el texto que ve el usuario.

## UI Premium 20080

Navegación: `Resumen | Cargos | Automatizaciones | Pagos | Recibos | Informes`.

El estado de filtros es compartido entre KPI, gráfico, antigüedad, cargos, pagos, recibos e informe de vista. Los filtros incluyen año, mes, alumno, grupo, disciplina, categoría, estado, regla, método y antigüedad.

El gráfico principal presenta tres barras accesibles por mes: Generado, Cobrado y Pendiente. Cada barra tiene `title`, `aria-label` y navegación por click/tap que fija mes y estado semántico.

`+ Nuevo cargo` implementa los ocho pasos definidos: categoría, concepto, destinatarios, importe, periodo, vencimiento, observaciones y preview. El botón de escritura solo aparece al final del preview server-side.

Las automatizaciones pueden guardarse en pausa o activas y cuentan con simulación shadow. La UI 20080 no expone `shadow=false` para recurrencias.

## Orden de rollout

1. Aplicar `143_kombax_finance_premium_v2_20079.sql` del paquete 20080.
2. Aplicar inmediatamente `144_kombax_finance_premium_dashboard_v2_20080.sql`.
3. Desplegar `finance-recurring` manteniendo ejecución shadow.
4. Desplegar web 20080.
5. Verificar Finanzas RC13 con todos los flags en false.
6. En el club piloto: activar `finance_v2_enabled=true`.
7. Activar `finance_dashboard_v2_enabled=true`.
8. Validar filtros, wizard, pagos por validar, recibos y automatizaciones en pausa/simulación.
9. Mantener `finance_recurring_enabled=false` hasta completar comparación shadow y QA de idempotencia.
10. `finance_reports_enabled` permanece false hasta incorporar PDF/snapshot/storage privado.

## Rollback

Para UI: desactivar `finance_dashboard_v2_enabled` o `finance_v2_enabled` y volver a entrar en Finanzas. RC13 permanece intacto.

Para recurrencias: conservar/desactivar `finance_recurring_enabled`. No borrar cargos históricos para corregir: usar anulación, excepción, ajuste o nueva versión según el contrato financiero.

## Invariantes verificadas por test estático

- flags inicialmente false;
- recurrencia shadow por defecto;
- UNIQUE club + regla + alumno + ciclo;
- no borrado/reescritura de pagos o recibos históricos;
- un solo gateway de escritura con request_id;
- backend_version exacto del runtime RC13;
- preview antes de cargo masivo;
- filtros de pagos/recibos derivados del mismo CTE que el dashboard;
- no se inserta dinero/pagos desde Finance V2;
- eventos financieros reutilizan `notificaciones`;
- no se expone `shadow=false` en la UI.

## Pendiente para 20081+

- PDF financiero Premium persistente con snapshot histórico, identificador y página X/Y.
- storage privado, políticas y signed URLs de informes.
- informe individual de estado de cuenta.
- snapshot histórico explícito de grupo/disciplina por cargo; en 20080 esos filtros usan membresía activa actual y la API lo declara como `group_discipline_scope=current_active_membership`.
- selección múltiple avanzada y acciones masivas adicionales con preview.
- persistencia por usuario de columnas/densidad.
- políticas opcionales de prorrateo; siguen desactivadas.
