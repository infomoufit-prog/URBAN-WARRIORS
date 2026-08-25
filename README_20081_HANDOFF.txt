KOMBAX RC13 build 20081 · FINANCE PREMIUM REPORTS

Candidato acumulativo sobre 20080.

Incluye:
- 143 Finance Premium Foundation corregida.
- 144 Dashboard Premium + cargos manuales.
- 145 Informes históricos, snapshot inmutable, storage privado y gateway.
- Edge Function finance-recurring (sigue shadow por defecto).
- Edge Function finance-report (PDF A4 privado, hash SHA-256, JWT y service-role attach).
- UI Informes Premium: informe de vista, catálogo de informes, histórico, signed PDF,
  versión actualizada y estado de cuenta individual.
- tests estáticos 20079, 20080 y 20081.

NO APLICADO A PRODUCCIÓN EN ESTE PAQUETE.
Flags recomendados durante instalación/QA:
finance_v2_enabled=false
finance_dashboard_v2_enabled=false
finance_recurring_enabled=false
finance_reports_enabled=false

Orden futuro del piloto: 143 -> 144 -> 145 -> deploy edge functions -> web 20081 ->
activar v2/dashboard -> activar reports -> QA -> recurrencias siguen en shadow/false.
