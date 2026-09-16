# KOMBAX R62.2 — Finanzas Premium y Migrations

## Cambios

- Finanzas Premium muestra `Activar cobros con tarjeta` como una acción compacta junto a `Nuevo cargo` y `Nueva automatización`.
- Se eliminó de esa cabecera el panel desplegado de estados de Stripe Connect.
- Las llamadas a Supabase Edge Functions ya no envían la cabecera `Prefer`, reservada ahora para PostgREST. Esto evita que el navegador bloquee por CORS la eliminación de conversaciones y otras funciones.

## Verificación

- QA R60 Migrations: 33/33.
- QA R61 pagos y commerce: PASS.
- Sintaxis de los módulos modificados: PASS.
- Build: 197 archivos; web = dist = Android.
- Prueba autenticada: una conversación de Migrations eliminada correctamente, sin errores nuevos en consola.
- Verificación visual: botón compacto visible y panel de estados ausente en Finanzas Premium.

## Flujo de cobro

- `Nuevo cargo` registra la deuda en KOMBAX.
- El pago con tarjeta se inicia sobre ese cargo y se procesa directamente en la cuenta Stripe conectada del club.
- `Nueva automatización` crea los cargos en la fecha programada. El débito automático de una tarjeta guardada requerirá un consentimiento/mandato específico y un flujo separado; no se presenta como activo en este piloto.
