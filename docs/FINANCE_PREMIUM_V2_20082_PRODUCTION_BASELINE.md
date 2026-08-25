# KOMBAX Finance Premium 20082 · baseline producción (solo lectura)

Fecha: 2026-08-25
Proyecto Supabase: producción KOMBAX (`poggsobhtutbuagjiydc`)

Esta comprobación no ejecutó DDL ni mutaciones.

## Estado observado antes de instalar 20082
- Cargos (`cuotas`): 13
- Pagos: 8
- Recibos: 6
- Sobrepagos validados: 0
- Recibos activos emitidos con saldo pendiente: 0
- Cargos en estado `pagada` sin recibo activo: 0
- Pagos pendientes de validación: 2

Los 2 pagos pendientes de validación son un estado válido y deben permanecer fuera del total cobrado hasta validación.

## Capacidades PostgreSQL verificadas
- `pg_try_advisory_xact_lock(bigint)`: disponible.
- `hashtextextended(text,bigint)`: disponible.
- `tiene_rol_club(uuid,rol_club[])`: disponible.
- `v_estado_cuenta_socio`: disponible.

Conclusión: no se detectan anomalías críticas previas en los datos financieros actuales y el servidor dispone de las primitivas necesarias para el gate/concurrency hardening de 20082.
