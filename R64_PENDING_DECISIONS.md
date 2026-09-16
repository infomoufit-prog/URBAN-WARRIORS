# KOMBAX 20.112 R64 - Pendientes explícitos

1. **Partner + pago anual**: no existe todavía una regla aprobada para convertir “12 mensualidades desde la segunda cuota” en una liquidación cuando el referido paga anual. R64 registra el caso como pendiente y no inventa un payout.
2. **Cobro recurrente SaaS real**: R63 posee motor de planes/capabilities, pero no un ciclo completo de Stripe Billing recurrente con Price IDs preparado para estas nuevas tarifas. R64 expone contratación y registra solicitudes auditables; conectar el cargo recurrente real requiere una fase específica y autorización de pagos reales.
3. **Legal**: textos comerciales y contratos deben recibir revisión legal/fiscal final antes de producción, especialmente platform fee, gastos de gestión Ticketing, reembolsos y Partner.
4. **Producción**: migraciones, Stripe live, Netlify, GitHub, APK/AAB y Play no se han ejecutado.
5. **Android signing**: falta `android/keystore.properties` local en el paquete de trabajo; no se ha generado release firmado.
