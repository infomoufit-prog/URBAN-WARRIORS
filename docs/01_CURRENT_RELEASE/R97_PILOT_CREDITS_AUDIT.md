# KOMBAX R97 · Auditoría previa de piloto y Créditos IA

Base examinada: ZIP acumulativo R96 (`KOMBAX_20149_R96_MIGRATION_IMPORT_ACCUMULATIVE_FINAL.zip`). Fecha: 25 septiembre 2026.

## Ya existe y se conserva

- Gestión de clubes, membresías, tutores, fichas e importación R96: se mantienen sus tablas, RPC y permisos.
- Assist y Migrations comparten `kombax_ai_ops.resolve_context`, `assistance_turns`, tarifas de modelo y el servicio `kombax-assist-r38`. La función ya registra tokens y coste por interacción. Existen límites de gasto internos y de tamaño de lotes.
- La identidad activa está vinculada a `tenant_ref` (`club:<uuid>` o `profile:<uuid>`). Los tickets y turnos conservan esta referencia, útil para multiclub.
- `kombax_commercial.runtime_config_r64`, `organization_terms_r64`, planes y entitlements proporcionan el punto de integración comercial.
- El panel de Assist ya muestra cuotas de conversación y migración; el administrador ya tiene un panel de preparación del piloto.

## Falta o está incompleto

- No existe calendario central operativo del piloto ni estado persistente de inscripción y transición a fundador.
- Las ventajas de los dos clubes fundadores y Urban Warriors no están asignadas a entidades identificadas ni existe una secuencia temporal de beneficios.
- No existe monedero único de Créditos IA, asientos, reserva atómica, consumo por uso real ni informe de saldo para Assist y Migrations.
- Las cuotas actuales cuentan casos/conversaciones. Son controles heredados y se conservan durante la validación del nuevo medidor.
- No existe trial público seguro: registro, verificación, datos de demostración, guardas previas al almacenamiento ni conversión a cliente.
- La analítica administrativa actual no mide créditos otorgados/usados ni cohortes del piloto.

## Intervención sobre la arquitectura actual

1. Añadir configuración de fechas y tarifas a `runtime_config_r64`; mantener sin fecha el lanzamiento oficial hasta decisión expresa.
2. Añadir inscripción y beneficios por ID de entidad, con transición calculada por fecha. No elegir clubes a partir del nombre o datos de demostración.
3. Extender el registro existente `assistance_turns` con reservas y cargos atómicos en un solo monedero por `tenant_ref`. La tarificación procede de `model_cost_rates` y del factor configurable de créditos. Conservar las barreras de coste existentes en esta versión.
4. Mostrar saldo agregado y métricas sin exponer precio, modelo ni tokens al cliente; ofrecer el detalle económico solo a propietarios autorizados.
5. Mantener el trial desactivado hasta que estén completas y probadas las barreras de privacidad anteriores a todo guardado. Los clubes piloto reales quedan fuera de esas restricciones.

## Riesgos y decisiones pendientes

- No están confirmados los ID de los 4–5 clubes piloto, de los dos beneficiarios de seis meses ni de Urban Warriors. Se prepara asignación explícita por administrador, sin conceder beneficios a una entidad equivocada.
- El lanzamiento de enero 2027 es una ventana prevista, no una fecha exacta: la configuración de activación permanece vacía.
- Los datos reales y de menores del piloto requieren las reglas normales de KOMBAX. El trial futuro exige un circuito separado de demostración y revisión antes de aceptar importaciones reales.
- La reserva de créditos debe ser transaccional e idempotente; se valida concurrencia y reintentos antes de activar su bloqueo como autoridad única.
