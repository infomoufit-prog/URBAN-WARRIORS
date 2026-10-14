# Riesgos y controles

1. **Compatibilidad live:** vistas existentes mantienen nombre, número y tipos de columnas y `security_invoker=true`.
2. **Roles simultáneos:** seleccionar rol Tesorería en frontend no concede permisos en DB; Supabase vuelve a validar membresía real.
3. **Pagos y Stripe:** anulaciones se rechazan si existe cualquier registro de pago o recibo, o referencia Stripe.
4. **Auditoría:** los importes originales se preservan en `cuotas` y tabla auditada (protegida por RLS).
5. **Versionado SW:** no publicar frontend hasta revisar R118/build 20178 frente a R120 FIX22 y caché Android/PWA.
6. **Informes históricos:** los ingresos importados de periodos pasados deben interpretarse con su periodo; quedan pendientes escenarios de consolidación contable.
7. **Pruebas de producción:** no realizados cambios de datos ni pruebas destructivas. Usar ambiente de QA.
