# R64.4 - Informe de implementación

## Objetivo

Consolidar el modelo comercial final y hacer Destacar más accesible sin alterar el motor de promociones ni los límites de frecuencia.

## Cambios acumulativos consolidados

### Urban Warriors
- Premium activo de piloto.
- Showcase hasta 25 modelos.
- Commerce incluido por plan.
- 2 Events públicos/mes.
- Ticketing puntual.
- Platform fee 1,5 %.

### Club básico
- Showcase Display habilitado hasta 15 modelos.
- Puede crear/publicar fichas de producto sin Commerce.
- Commerce opcional 12 EUR por 30 días, renovable mes a mes.
- Events públicos mediante activación puntual.
- Ticketing puntual por capacidad.

### Premium
- Showcase hasta 25 modelos.
- Commerce incluido.
- 2 Events públicos/mes.
- Ticketing puntual.

### Enterprise
- Showcase ilimitado.
- Commerce incluido.
- Events ilimitados.
- Ticketing incluido.
- 0 % platform fee.

### Navegación / altas
- Club -> Showcase abre gestión del escaparate.
- Área de Club expone KOMBAX Events.
- La elección de Club/Premium/Enterprise aparece antes de completar solicitud de alta.
- La solicitud conserva verificación documental.
- Administración dispone de solicitudes comerciales auditables.
- Se retiró de cliente el bloque “cuándo compensa Enterprise”.

### Events
- Crear borrador y publicar permanecen separados.
- Publicación puntual se liga a un Event concreto.
- Publicar != Destacar != Ticketing.

### Ticketing
- Se eliminó el fee fijo de 1,50 EUR por entrada al comprador.
- Activación por capacidad: 50/100/200/500/1.000 -> 10/15/25/45/75 EUR.
- >1.000 -> Gran Evento.
- QR, lector y control de acceso siguen incluidos.

### Destacar - R64.4
- 7 días: 3 EUR.
- 15 días: 5 EUR.
- 30 días: 8 EUR.
- Aplica a Events y productos Showcase.
- Mantiene prioridad de módulo + amplificación KOMBAX Social.
- Mantiene los frequency caps existentes.

### Stripe Connect
- Se mantiene Standard + direct charges.
- `stripe-checkout` acepta `platform_fee_minor` y lo envía como `payment_intent_data[application_fee_amount]`.
- Se mantiene gate 18+ para Showcase/Tickets.
- Ticketing buyer fee queda 0.
- Edge Function `stripe-checkout` desplegada como versión 10 con JWT requerido.

### Documentación
- PDF comercial actualizado a R64.4.
- PDF accesible desde Plan y servicios.
- Snapshot frontend + configuración Supabase alineados.
