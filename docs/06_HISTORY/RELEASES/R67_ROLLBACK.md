# R67 · rollback / recuperación

R67 no introduce migraciones de base de datos. Por tanto el rollback de esta release es principalmente de frontend/versionado.

## Si R67 presenta un defecto UX

1. Volver a la fuente R66 build 20117 para `web/**` y assets Android embebidos.
2. Mantener las migraciones R66 live; no eliminarlas.
3. Mantener R65/R66 Commerce, Events, refunds, Finance, BI y Stripe Connect intactos.
4. Volver a sincronizar `dist/**` y `android/app/src/main/assets/www/**` desde la fuente elegida.
5. Actualizar `health` para que refleje el build realmente desplegado.
6. Ejecutar de nuevo la regresión correspondiente antes de cualquier despliegue.

## No hacer

- No borrar ledgers de pagos/refunds.
- No revertir manualmente pagos Stripe.
- No eliminar las migraciones R66 del historial live.
- No activar KOMBAX SaaS Billing como parte de un rollback.

Como no se ha desplegado R67 a Netlify/GitHub/Google Play desde esta entrega, no existe un rollback de esos destinos asociado a este paquete.
