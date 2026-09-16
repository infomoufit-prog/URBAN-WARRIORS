# KOMBAX 20.112 R64 - Informe de implementación comercial

## Pricing final implementado
### Clubes
- Club: Founder 29 €/mes · estándar 36 €/mes · anual estándar 363 €.
- Premium: Founder 47 €/mes · estándar 59 €/mes · anual estándar 595 €.
- Enterprise: Founder 79 €/mes · estándar 99 €/mes · anual estándar 998 €.
- Platform fee: Club/Premium 1,5 % · Enterprise 0 %.

### Marcas
- Brand Start: 39 / 49 / 494 € · 25 modelos · fee 1,5 %.
- Brand Growth: 69 / 89 / 897 € · 100 modelos · 2 Events/mes · fee 1,5 %.
- Brand Enterprise: 129 / 161 / 1.623 € · ilimitado · fee 0 %.

### Federación
- Founder 19 €/mes · estándar 24 €/mes · anual 242 €.
- Partner: 25 % con 1-9 clubes activos referidos; 30 % desde 10 o acuerdo de Federación; base imponible sin IVA; mensualidades 2-13; bonificación 100 % de la cuota Federation con 5 clubes de pago activos.
- La liquidación Partner de referidos con pago anual queda deliberadamente `pending` hasta decisión comercial expresa.

## Founder y anual
- Founder se conserva mientras la relación de cliente no se interrumpa.
- Si se pierde por baja, no se vuelve a conceder automáticamente al reingresar.
- Descuento anual estándar: 16 %.
- Founder no acumula descuento anual; prepago Founder = 12 × mensual Founder.

## Showcase
- Premium: máximo 15 modelos activos; variantes no consumen cupo; archivados no consumen cupo.
- Commerce temporal Premium: 7d 9 €, 30d 19 €, 90d 59 €.
- Anticanibalización: máximo 120 días activos/12 meses móviles, 90 consecutivos y 30 días de cooldown tras 90 consecutivos.
- Commerce agrupa checkout, Stripe Connect, pedidos, stock, seguimiento y posventa.

## Events
- `Publicar != Destacar != Ticketing`.
- Premium: 2 Events públicos/mes natural.
- Publicación puntual: 7/15/30/60 días = 5/8/12/18 €.
- Destacar único: 7/15/30 días = 15/24/35 €, con prioridad en Events o Showcase y amplificación automática en Social.
- Frequency caps iniciales: máximo 2 eventos promovidos por usuario/día; nunca dos promociones consecutivas; mismo evento como máximo una vez/72 h.

## Ticketing
- 1,50 € por entrada como gastos de gestión pagados por el comprador.
- Incluye ticket digital, QR, lector, control de acceso, tipos/cupos, panel, cancelaciones y reembolsos.
- >1.000 entradas: `Gran Evento`, condiciones específicas.
- Enterprise/Brand Enterprise incluyen Ticketing; Club/Premium y otros perfiles elegibles lo usan de forma puntual.

## Stripe
- Se conserva Connect Standard + direct charges.
- El importe principal se cobra en la cuenta conectada del vendedor/organizador.
- R64 prepara `application_fee_amount` según plan y servicio.
- En Ticketing, el application fee puede incluir los gastos de gestión del comprador más el platform fee del organizador cuando corresponda.
- No se ha ejecutado ningún cobro real.

## Interfaz
- Nueva capa `Plan y servicios` para Club, Marca y Federación.
- Tabla simplificada: Gestión, Social/membresías, Showcase, Commerce, Events, Ticketing, Destacar, Assist, Migrations y platform fee.
- PDF comercial accesible desde interfaz.
- Solicitudes de plan/activaciones quedan auditadas; no se finge un alta recurrente de Stripe Billing que R63 no tenía implementada de extremo a extremo.

## Assist y Migrations
- Assist Base/Plus/Pro: 10/30/100 conversaciones/mes.
- Migrations Base/Plus/Pro: 2/10/30 procesos/mes.
- Marca usa el mismo motor Migrations ya existente, sin sistema paralelo.
