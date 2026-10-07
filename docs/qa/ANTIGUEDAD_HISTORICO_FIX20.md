# Antigüedad y movimientos anteriores

Implementación local; no aplicada en producción. Incluida en el acumulativo FIX20 junto con Meta/Instagram.

## Uso
En Mi Club > Alumnos > Nuevo alumno / Editar alumno aparece Fecha de incorporación al club. Puede ser anterior al registro en KOMBAX; no puede ser futura ni anterior al nacimiento. Si se deja vacía, se conserva el valor existente y en una ficha nueva se utiliza el alta actual. No cambia la creación de la cuenta ni altera automáticamente la antigüedad de cada matrícula/grupo.

En Finanzas básico y Premium, los roles autorizados para registrar cobros disponen de Registrar histórico:
- Cuota anterior pendiente: alumno, concepto, importe, periodo y vencimiento original. No crea pago.
- Pago anterior ya realizado: además exige fecha real del pago y método. Crea cuota y pago validado en una sola transacción, reutilizando registrar_cobro_cuota y el circuito existente de recibos.

Los avisos de las cuotas históricas quedan pausados inicialmente. Pueden reactivarse con las acciones habituales; registrar histórico no ejecuta Stripe, SEPA ni transferencias. El registro conserva fecha de creación actual y fechas contables originales. No falsifica la fecha de emisión de documentos. El ejercicio/fecha del pago se toma del pago histórico según el circuito existente.

## Cambios
Migración: supabase/migrations/20261007195031_member_seniority_historical_finance_fix20.sql.
RPC: app_kombax_historical_finance_fix20. Registro idempotente privado con RLS; exige permisos del club y pertenencia exacta del alumno. Wrapper de app_kombax_member_batch_mutate_r120 conserva el alta multigrupo/multidisciplina y añade la fecha de incorporación.
Frontend: web/js/modules/historical-finance.js; groups-members.js; finance.js; finance-premium.js; core/repositories.js; i18n/meta-instagram-copy.js. Se aplica a todos los clubes, incluidos los piloto, respetando sus permisos actuales.

## Verificación
29 comprobaciones PostgreSQL aisladas: fechas, estado pagado/pendiente, importes, permisos, aislamiento entre clubes, RLS, reintentos y no modificación de creado_en. Se ejecuta la función real registrar_cobro_cuota del repositorio; la dependencia de guardado multigrupo está simulada. No es una prueba de producción ni una verificación nueva del PDF de recibos.
18 comprobaciones de navegador con transporte simulado en móvil y escritorio: campos condicionales, fecha requerida, datos enviados, identificadores de reintento y ausencia de desbordamiento.
Protección contra reenvío del mismo formulario; abrir otro formulario crea un registro distinto. Antes de introducir manualmente un histórico ya importado debe comprobarse que no exista. No se consolidan automáticamente cargos similares.
Los recibos se mantienen en su circuito existente. No se ha generado una factura fiscal nueva ni se ha validado normativa contable externa.
