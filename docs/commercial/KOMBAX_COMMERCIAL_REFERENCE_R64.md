# KOMBAX - Referencia comercial R64.4

La fuente de verdad ejecutable es `kombax_commercial.plan_pricing_r64` + `runtime_config_r64` cuando las migraciones estén aplicadas. `web/js/core/commercial-pricing.js` es el snapshot/fallback de interfaz previo a migración.

El PDF `KOMBAX_PLAN_PRECIOS.pdf` es una representación comercial y debe mantenerse alineado con la configuración; no debe convertirse en una fuente de precios independiente.

Principios:
- Social gratis.
- Founder se conserva mientras no haya interrupción.
- Anual estándar -16 %, no acumulable con Founder.
- Club/Premium y Brand Start/Growth: fee 1,5 %; Enterprise: 0 %.
- Publicar != Destacar != Ticketing.
- Ticketing = activación puntual por capacidad: 50/100/200/500/1.000 entradas; >1.000 = Gran Evento. Incluye QR/control de acceso y no añade fee fijo por entrada al comprador.
- Destacar es único para Events/Showcase y amplifica en Social.
- Destacar: 7 días 3 € · 15 días 5 € · 30 días 8 € (IVA incluido cuando corresponda).
- Toda compra comercial exige 18+.


R64.4 onboarding/operativa:
- Urban Warriors queda en plan Premium activo de piloto, con Showcase + Commerce hasta 25 modelos y 2 Events/mes.
- El alta de Club muestra planes antes de la solicitud y guarda plan + modalidad para la cola comercial.
- `Plan y servicios` no muestra cálculos de break-even Enterprise.
- Publicación puntual de Events se solicita desde un evento concreto; Club base puede preparar borradores.
- Administración puede revisar planes y activaciones puntuales sin simular un cobro SaaS.

- Club básico incluye Showcase Display hasta 15 modelos y puede activar Commerce por 12 €/mes, renovable mes a mes.
- Premium incluye Showcase + Commerce hasta 25 modelos.
