# INFORME FINAL - KOMBAX 20.115 R64.4

**Estado:** QA READY / no Production Ready.

## Resumen ejecutivo

R64.4 consolida el modelo comercial actual y aplica el último cambio aprobado: Destacar pasa a 3/5/8 EUR. La configuración de Supabase, el fallback frontend, la UI de Events/Showcase y el PDF quedan alineados.

El backend real confirma Urban Warriors como Premium activo. Stripe Checkout se ha actualizado para soportar el platform fee mediante `application_fee_amount` manteniendo direct charges.

## Modelo Club vigente

- Club: 29 EUR Founder / 36 EUR estándar; Showcase 15; Commerce 12 EUR/30 días; Events/Ticketing puntuales; fee 1,5 %.
- Premium: 47 / 59 EUR; Showcase 25 + Commerce incluido; 2 Events/mes; Ticketing puntual; fee 1,5 %.
- Enterprise: 79 / 99 EUR; Showcase/Commerce/Events/Ticketing incluidos sin límite comercial ordinario; fee 0 %.

## Activaciones vigentes

- Publicación Events: 5/8/12/18 EUR.
- Destacar: 3/5/8 EUR.
- Ticketing: 10/15/25/45/75 EUR hasta 50/100/200/500/1.000 entradas.
- Gran Evento >1.000: condiciones específicas.

## Verificación técnica

- QA R64.4: 12/12 PASS.
- Regresión crítica: PASS.
- Build determinista: 206 archivos, web=dist=Android.
- Android preflight: 4/5; falta firma local.
- PDF comercial: 6 páginas, render verificado.
- Supabase: configuración Destacar 3/5/8 verificada.
- Supabase: Urban Warriors Premium activo verificado.
- Edge `stripe-checkout`: versión 10 activa, JWT=true, application fee soportado.

## No desplegado

Netlify, GitHub, Play Store y Android release permanecen sin tocar.
