# KOMBAX 20.112 R64 - Estrategia de rollback

R64 usa migraciones acumulativas. No se recomienda borrar tablas/columnas después de aplicar una migración en producción.

## Antes de aplicar Supabase
Rollback inmediato: mantener R63 desplegada y no ejecutar las migraciones R64. El ZIP R64 no realiza cambios externos por sí solo.

## Si las migraciones R64 ya se aplicaron
Usar una **migración compensatoria**, no editar el historial aplicado:
1. cerrar nuevas ventas Founder (`founder_sales_open=false`);
2. deshabilitar/ocultar Plan y servicios R64 mediante feature/config;
3. restaurar reglas de fee mediante una migración compensatoria solo si la decisión comercial lo exige;
4. cancelar o finalizar entitlements R64 que no deban continuar;
5. mantener tablas R64 para auditoría, sin borrarlas;
6. restaurar frontend R63 si hace falta;
7. verificar que direct charges y contratos existentes siguen operativos.

## Stripe
No eliminar cuentas Connect ni objetos Stripe para hacer rollback. Ajustar únicamente reglas de application fee en backend/config y conservar trazabilidad.

## Datos Partner/Founder
Nunca borrar historial de Founder, referrals, solicitudes o rewards. Corregir estado mediante eventos/migraciones compensatorias.
