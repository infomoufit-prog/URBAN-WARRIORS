# Urban Warriors RC12 · build 20016

## Resultado local

- `npm test`: aprobado.
- `npm run build`: aprobado; 45 archivos idénticos entre `web`, `dist` y los assets Android.
- JavaScript: sintaxis aprobada y grafo de imports resuelto.
- Arquitectura: 74/74 operaciones del contrato backend implementadas.
- Regresión: RC4–RC10 y releases B–J aprobadas.
- RC12 finanzas/recibos: aprobada estáticamente.

## Cambios RC12

- Los filtros de año, mes, alumno, origen y estado gobiernan también indicadores, cargos, pagos, recibos y alertas.
- El panel separa cuota, material y otros en importes generado, cobrado, pendiente y vencido.
- El formulario de cobro propone el saldo del cargo concreto, no el total combinado, y admite pagos parciales.
- El portal identifica el origen de cada cargo y recibo.
- Un cargo completamente pagado emite un único recibo.
- El recibo de material conserva el artículo, origen e importe; ya no muestra la disciplina como concepto.
- Un pago parcial no emite recibo final.
- Se mantienen el menú móvil desplazable, el mismo botón para abrir/cerrar y la persistencia del formulario al volver del selector de imágenes.

## Puerta obligatoria antes de Netlify

La aprobación local no sustituye la prueba de producción. Ejecutar en Supabase, por orden:

1. `supabase/verification/preflight_031_finance_receipts.sql`
2. `supabase/migrations/031_finance_receipts_breakdown.sql`
3. `supabase/verification/verify_031_finance_receipts.sql`
4. `supabase/verification/test_031_receipts_transactional.sql`

Todos los controles deben devolver `OK`; `pagados_sin_recibo` debe ser cero y la prueba debe mostrar 7/7 `OK` antes de su `ROLLBACK`.

Después se prueba con cuentas reales: cobrar por completo una cuota, cobrar por completo un material, registrar un pago parcial y comprobar concepto, importe, saldo y recibo visible en escritorio y móvil.

## APK

Proyecto Android preparado con `versionCode 20016` y `versionName 2.0.0-rc.12`. No se ha generado ni firmado ninguna APK dentro de esta certificación.
