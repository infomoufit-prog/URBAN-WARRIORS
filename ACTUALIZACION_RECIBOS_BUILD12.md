# Urban Warriors 1.6.0 build 12 — recibos de cuota

## Qué incorpora

- Emisión automática de recibo cuando una cuota queda en estado `pagada`.
- Numeración anual única: `UW-AAAA-000001`.
- Recibo breve con logo Urban Warriors, diseño negro y datos esenciales:
  - socio,
  - actividad,
  - mes,
  - importe,
  - pagado por,
  - fecha,
  - número de recibo.
- Lectura para socio/tutor y para Dirección, Tesorería/Economía y Secretaría.
- Botón **Ver recibo** desde Finanzas/Cuotas.
- Descarga de PDF real generada en el dispositivo, sin librerías externas.
- Notificación interna: **Pago validado · recibo disponible**.
- Generación retroactiva para cuotas que ya estaban pagadas y todavía no tenían recibo.
- Registros de recibo sin edición directa desde navegador; la trazabilidad permanece separada de los justificantes.

## Orden seguro de instalación

1. Mantener la validación de guardados 1.6.0 actual hasta terminarla.
2. Ejecutar `supabase/migrations/016_recibos_cuota.sql` una sola vez en Supabase SQL Editor.
3. Ejecutar `PRUEBA_RECIBOS_V160.sql` y confirmar:
   - `ok = true`
   - `pagadas_sin_recibo = 0`
4. Solo después subir el parche build 12 a GitHub para incluirlo en el siguiente deploy web.

## Nota de despliegue

Este build mantiene el contrato de backend 1.6.0 y la puerta única `app_mutate_v160`. Los recibos son una consecuencia transaccional del estado de la cuota, por lo que no se añade una ruta de escritura paralela desde el navegador.
