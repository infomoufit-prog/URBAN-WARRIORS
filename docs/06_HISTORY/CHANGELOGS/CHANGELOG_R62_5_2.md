# KOMBAX R62.5.2 · Events Ticketing QR Access + Sticky Sidebar

## UX / navegación
- Sidebar desktop persistente al viewport durante feeds y vistas largas.
- Scroll interno del menú cuando supera la altura disponible.
- Comportamiento móvil existente preservado.

## Events / tickets
- Ticket digital individual con identidad del evento, organizador, pedido, precio, estado y QR único.
- Un pedido de N entradas mantiene la emisión exacta de N tickets ya garantizada por R62.5.
- QR opaco `KXEVT:<ticket_token>` sin PII, precio ni correo embebidos.
- Contacto del organizador configurable por evento.
- Texto coherente del rol de KOMBAX como plataforma tecnológica de ticketing y del organizador como responsable de la celebración/cancelación del evento.
- Dashboard del evento con aforo, pagadas, reservas Checkout, usadas, pendientes de acceso, reembolsadas, anuladas, disponibles e ingresos confirmados.

## Control de acceso
- Lector QR integrado en la propia gestión del evento.
- Cámara mediante APIs del navegador/PWA/Android cuando están disponibles y código manual como fallback.
- Check-in server-side atómico con bloqueo de fila (`FOR UPDATE`).
- Respuestas: válida, ya utilizada, reembolsada, anulada, otro evento e inválida.
- Auditoría de escaneos con fingerprint SHA-256; el QR no se guarda en claro.
- Roles por evento: `ticketing_manager`, `access_control`, `box_office`.
- El personal de puerta/taquilla no recibe permisos sobre Stripe ni configuración general del evento.

## Supabase
- Migración remota R62.5.2 aplicada sobre el proyecto KOMBAX actual.
- Tablas privadas `event_ticket_access_staff` y `event_ticket_checkin_audit` con RLS y sin acceso directo de cliente.
- RPC autenticadas con autorización server-side y `search_path=''`.
- Hardening de índices tras revisión del advisor de rendimiento.

## No incluido
- Sin deploy de frontend a Netlify.
- Sin push a GitHub.
- Sin modo offline de check-in en esta fase.
- Los cobros reales/Stripe LIVE no forman parte de QA; solo Stripe TEST debe usarse para estabilización.
