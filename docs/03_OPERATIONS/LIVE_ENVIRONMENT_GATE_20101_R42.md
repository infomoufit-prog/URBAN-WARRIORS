# KOMBAX R42 — Live Environment / Real Data Gate

## Estado actual
**Código estático / freeze candidate: PASS**
**PRE-QA: READY**
**Datos reales de clubes/miembros: HOLD**

## Condiciones mínimas para levantar HOLD
- [ ] QA manual móvil/desktop completado.
- [ ] QA por roles e identidades completado.
- [ ] Aislamiento multitenant probado contra backend real/staging equivalente.
- [ ] RLS/RPC/GRANT/Storage policies revisadas en Supabase vivo.
- [ ] Supabase Security Advisors capturados y tratados.
- [ ] Credenciales y variables por entorno revisadas.
- [ ] Backup + restore + rollback evidenciados.
- [ ] Logging/monitorización/alertas preparados.
- [ ] Revisión humana de código/diff completada.
- [ ] Revisión de ciberseguridad completada.
- [ ] Autorización explícita de entrada a piloto real.

## Regla de preservación
Si durante QA aparece una corrección, debe implementarse sobre esta R42 freeze candidate de forma aislada, documentar diff, ejecutar nuevamente targeted + full regression + build parity y emitir una nueva revisión. No convertir una rama experimental en baseline sin repetir los gates.
