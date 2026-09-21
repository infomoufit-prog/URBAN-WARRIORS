# R62.5.1 · Matriz de pruebas para agentes IA

Todos los agentes deben usar datos de TEST. Prohibido destruir, truncar, resetear o manipular producción. Prohibido publicar secretos.

## Agent 1 · AUTHZ / Tenant Isolation
Objetivo: intentar IDOR/BOLA en Club, Marca, Federación y Organizador de evento.
Pruebas: alterar subject_id, reference_id, event_id, provider_id y order_id; usar roles sin privilegios; comprobar que no se filtran ventas, pedidos, tickets o Connect de otra entidad.
Éxito: todas las operaciones cruzadas son rechazadas y no dejan efectos laterales.

## Agent 2 · Stripe Connect State
Objetivo: validar estados y callbacks.
Pruebas: not_configured, onboarding, verification_pending, action_required, restricted, active; refresh_url; return_url; cuenta existente; intento de reasignar acct_xxx.
Éxito: nunca `active` sin charges_enabled+payouts_enabled; nunca se reemplaza silenciosamente una cuenta ya asociada.

## Agent 3 · Checkout Tampering
Objetivo: manipular cliente.
Pruebas: modificar amount, currency, stripe_account_id, seller, quantity, reference_id, request_id y metadata del request cliente.
Éxito: backend ignora valores no confiables y resuelve el importe/beneficiario real.

## Agent 4 · Idempotency / Replay
Objetivo: duplicados y reintentos.
Pruebas: doble clic, mismo request_id, timeouts, reintentos, webhook repetido, eventos fuera de orden.
Éxito: un pago lógico produce un solo pedido/pago y un solo conjunto de tickets; stock se decrementa una sola vez.

## Agent 5 · Ticket Capacity Race
Objetivo: sobreventa.
Pruebas: lanzar compras paralelas cuando quedan 1-3 entradas, expiración de reservas, quantity > limit, sold out.
Éxito: nunca se emiten más entradas que el aforo configurado; reservas expiradas liberan capacidad lógica.

## Agent 6 · Showcase Fulfilment
Objetivo: ciclo completo del pedido.
Pruebas: received/payment_confirmed/preparing/shipped/delivered/incident/refunded; tracking obligatorio; transición inválida.
Éxito: solo transiciones válidas; comprador y vendedor ven únicamente los datos que les corresponden.

## Agent 7 · Refund / Dispute
Objetivo: consistencia financiera.
Pruebas: refund Showcase, refund tickets, dispute, webhook repetido.
Éxito: estados consistentes; tickets reembolsados quedan invalidados; no hay platform fees.

## Agent 8 · Privacy / Public Event Surface
Objetivo: impedir filtración por UUID.
Pruebas: solicitar estado de entradas de evento no visible/privado, evento visible, evento gestionado.
Éxito: evento no visible no devuelve estado comercial; públicos sí reciben solo proyección agregada.

## Agent 9 · Secrets / Client Bundle
Objetivo: detectar exposición accidental.
Pruebas: buscar `sk_test_`, `sk_live_`, service_role, webhook secret en web/dist/Android, logs y errores.
Éxito: cero secretos en bundles y mensajes públicos.

## Agent 10 · UI / Regression
Objetivo: flujos desde interfaz.
Pruebas: móvil/desktop, volver/cerrar, Comprar/Me interesa, Mis pedidos, Mis entradas, Entradas y cobros, errores de Connect, checkout cancelado.
Éxito: no hay rutas huérfanas ni botones que disparen una acción distinta a la esperada.

## Evidencia obligatoria por agente
Cada agente debe devolver: identificador de caso, rol/entidad, precondición, pasos, resultado esperado, resultado real, evidencia, severidad, reproducibilidad y propuesta de corrección. No corregir automáticamente producción.
