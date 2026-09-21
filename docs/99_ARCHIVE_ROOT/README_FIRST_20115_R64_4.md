# KOMBAX 20.115 R64.4 - FINAL PRICING QA READY

Base acumulativa: R64.3 / R64.2 / R64.1 sobre R63.

Esta entrega consolida el modelo comercial aprobado y el último ajuste de Destacar a 3/5/8 EUR. No despliega frontend, GitHub, Netlify, Google Play ni firma Android.

Puntos de entrada de QA:
- `FINAL_REPORT_20115_R64_4.md`
- `docs/releases/R64_4_QA.md`
- `docs/releases/R64_4_PRICING_MATRIX.md`
- `docs/commercial/KOMBAX_PLAN_PRECIOS.pdf`
- `MANIFEST_SHA256_20115_R64_4.txt`

Backend Supabase verificado:
- Urban Warriors: Premium activo de piloto.
- Club: Showcase 15, Commerce mensual opcional 12 EUR.
- Premium: Showcase 25 + Commerce incluido + 2 Events/mes.
- Enterprise: Showcase/Events ilimitados + Commerce/Ticketing incluidos + fee 0 %.
- Ticketing puntual: 10/15/25/45/75 EUR según 50/100/200/500/1000 entradas.
- Destacar: 3/5/8 EUR para 7/15/30 días.
- `stripe-checkout` activo con `application_fee_amount` para el platform fee.
