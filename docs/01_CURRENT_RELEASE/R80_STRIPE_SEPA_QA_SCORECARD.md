# KOMBAX R80 · QA Scorecard Stripe + SEPA

| Control | Resultado |
|---|---|
| R80 test contractual | 26/26 PASS |
| Regresión `npm test` | PASS / EXIT 0 |
| Build determinista | 465 archivos, web = dist = Android |
| i18n | 0 unresolved |
| PDF guía | 13 páginas / PASS visual |
| Secret scan | PASS |
| Sensitive-file scan | PASS |
| Android preflight | 4/5 - falta solo firma local |
| Stripe docs compatibility | PASS: Connect + `sepa_debit_payments` + Checkout setup + delayed notification |
| Test real Stripe TEST | PENDIENTE OPERATIVO |

## Gate
**Código R80: PASS.**
**Go-live SEPA: NO hasta ejecutar el smoke Stripe TEST y aplicar migración/funciones en el backend objetivo.**
