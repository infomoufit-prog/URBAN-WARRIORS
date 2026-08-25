# KOMBAX RC13 build 20082 · Finance Premium QA + Shadow Gate

## Objetivo
20082 no activa cobros automáticos. Añade evidencia reproducible y un cierre técnico que impide una ejecución recurrente real hasta aprobar Shadow QA.

## Gate de activación
- `finance_qa_shadow_approved` nace en `false`.
- `finance_recurring_enabled=true` es rechazado mientras el QA no esté aprobado.
- Una ejecución real también comprueba el gate en backend, aunque el flag recurrente hubiera sido alterado fuera de la UI.
- Las ejecuciones reales del mismo club se serializan con un advisory transaction lock; Shadow puede ejecutarse en paralelo.
- Cambiar regla, destinatario o excepción revoca automáticamente la aprobación.

## Evidencia mínima para aprobar
1. Cero anomalías bloqueantes.
2. Al menos una regla activa.
3. Dos Shadow runs consecutivos con estado `ok`.
4. Misma fecha de proceso.
5. Misma huella determinista (reglas + destinatarios + excepciones + matrículas dinámicas + resumen).
6. Último Shadow realizado en las últimas 24 h.

## Anomalías bloqueantes
- Duplicado regla + alumno + ciclo.
- Duplicado de clave de generación.
- Pago validado por encima del cargo.
- Descuadre entre `v_estado_cuenta_socio.pagado_validado` y la suma real de pagos validados.
- Recibo activo mientras queda saldo.
- Cargo `pagada` sin recibo activo.
- Informe con metadata de archivo cuyo objeto privado no existe.

## Advertencias
- Regla activa sin destinatario.
- Pagos pendientes de validación (informativos; no cuentan como cobro).

## Secuencia de QA 20082
1. Aplicar 143, 144, 145 y 146 únicamente en entorno de validación.
2. Desplegar `finance-recurring` y `finance-report` con JWT/secretos correctos.
3. Mantener `finance_recurring_enabled=false`.
4. Activar únicamente los flags V2 necesarios para el club piloto de validación.
5. Abrir Finanzas → Automatizaciones → QA 20082.
6. Ejecutar Shadow QA dos veces sin cambiar configuración.
7. Comprobar huella idéntica y bloqueos = 0.
8. Probar cambios de regla/excepción y verificar que la aprobación se revoca.
9. Probar pagos comunicados/validados, parciales, recibos e informes.
10. Repetir Shadow dos veces y aprobar QA.
11. NO activar recurrencia real todavía: se reserva para 20083.

## Matriz funcional manual obligatoria
- Mensual / trimestral / semestral / anual / única.
- Alumno individual / grupo / disciplina / todos activos.
- Dedupe del mismo alumno alcanzado por scopes múltiples.
- Alta a mitad de periodo: sin prorrateo automático.
- Baja/pausa/exento/bonificación/importe personalizado/omitir ciclo.
- Doble clic, retry y llamadas concurrentes.
- Pago comunicado no modifica cobrado hasta validación.
- Pago parcial y pago completo.
- Rechazo y validación.
- Recibo solo con saldo cero; anulación conserva histórico.
- Dashboard, drill-down, aging y cross-filter.
- Snapshot/PDF, versionado, hash y signed URL.
- Dirección / Secretaría / Economía / Monitor / Alumno / Familia.
- Aislamiento multiclub.
- Desktop/PWA + Android/móvil.
- Pérdida de red/reintentos/fallback RC13.

## Rollback
Desactivar flags V2. No borrar cargos, pagos, recibos, informes ni ejecuciones. La aprobación QA puede revocarse independientemente.
