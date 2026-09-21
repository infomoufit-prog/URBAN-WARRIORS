# KOMBAX 20.110 R62.8 — Showcase Marketplace + Events Commercial Services

## Alcance implementado

- **Mis pedidos universal:** cualquier cuenta KOMBAX autenticada puede consultar sus compras de Showcase, estados, seguimiento e incidencias.
- **Responsabilidad de fulfillment:** el vendedor gestiona preparación, envío, tracking y entrega; cada transición queda trazada.
- **Showcase Marketplace:** las fichas se clasifican como `product` o `professional_service`. Solo los productos pueden activar checkout.
- **Servicios profesionales:** publicación/contacto sin checkout de producto; los perfiles profesionales pueden disponer de Showcase de servicios sin Seller Center de producto.
- **Seller Dashboard:** inventario, tipo/SKU, stock, bajo stock, agotado, vendidos/no vendidos, unidades, GMV y estados de pedidos.
- **Events:** separación entre `events_publish` (base) y `events_ticketing` (add-on por evento).
- **Contrato Events + Ticketing:** aceptación versionada de condiciones del organizador y acuerdo de ticketing antes de venta interna.
- **Owner:** cola específica de servicios comerciales y activación/suspensión/rechazo del add-on.
- **Stripe:** cargos directos al vendedor/organizador, fee transaccional KOMBAX = 0, checkout alojado por Stripe.
- **Legal:** operador visible actualizado a **KOMBAX SPAIN**; se eliminan nombre, NIF y domicilio personales de las páginas legales públicas.

## Gates de seguridad

Producto: vendedor KOMBAX aprobado + políticas vigentes + Stripe Connect activo.

Ticket: evento en modo KOMBAX + add-on Events + Ticketing activo + contratos aceptados + Stripe activo.

Los documentos legales R62.8 son borradores operativos de piloto y mantienen `legal_review_status=pending` hasta revisión jurídica profesional y cierre de datos fiscales/registrales de KOMBAX SPAIN.
