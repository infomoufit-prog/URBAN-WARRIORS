# KOMBAX 20.110 · R62.5.3 — Event Ticket Personalization

## Alcance
Evolución incremental sobre R62.5.2. Mantiene intactos Stripe Direct Charges, emisión idempotente, QR KOMBAX, check-in atómico, permisos de acceso y sidebar persistente.

## Ticket controlado por KOMBAX
- La estructura base del ticket, QR, código, estado, validación y textos legales siguen siendo no editables por el organizador.
- El ticket digital y el imprimible/PDF representan la misma entrada: mismo `ticket_id`, mismo `ticket_token`, mismo QR y mismo estado.
- Imprimir o guardar PDF no genera una nueva entrada ni un nuevo QR.

## Personalización por evento
Dentro de `Evento > Gestionar > Entradas y cobros > Ticket` se incorporan:
- acento visual limitado a paletas seguras KOMBAX (`cyan`, `gold`, `red`, `violet`);
- uso opcional del banner ya asociado al evento;
- selección de hasta 6 logos de entidades ya vinculadas y aceptadas en el evento;
- apertura de puertas (máx. 80 caracteres);
- punto de acceso (máx. 120 caracteres);
- instrucciones breves (máx. 250 caracteres);
- contacto del organizador ya integrado en la configuración de ticketing;
- preview del ticket con composición controlada por KOMBAX.

No existe editor libre de HTML/CSS, URLs arbitrarias de logos ni edición de las cláusulas legales.

## Datos y seguridad
Migración remota aplicada: `20260911085236_kombax_r6253_event_ticket_personalization`.

Nuevas RPC:
- `app_kombax_event_ticketing_manage_status_r6253`
- `app_kombax_event_ticketing_mutate_r6253`
- `app_kombax_my_event_tickets_r6253`

Las tres requieren usuario autenticado. `anon` no dispone de `EXECUTE`. Las funciones `SECURITY DEFINER` fijan `search_path=''` y las entidades seleccionadas como logos se validan server-side contra el mismo evento y estado aceptado.

## Frontend
- Wallet de `Mis entradas` consume la proyección R62.5.3.
- Ticket digital incorpora identidad visual/configuración del evento sin alterar el QR.
- Acción `Imprimir / Guardar PDF` genera una representación imprimible del mismo ticket.
- Configuración de venta y ticket se presenta en una única experiencia de gestión.

## No realizado
- No se ha desplegado Netlify.
- No se ha hecho push a GitHub.
- No se han realizado cargos Stripe LIVE.
- Stripe TEST E2E autenticado sigue requiriendo la prueba interactiva prevista para piloto.
