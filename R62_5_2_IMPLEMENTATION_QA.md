# KOMBAX R62.5.2 · Events Ticket QR Access + Persistent Sidebar

## Implementado
- Sidebar desktop persistente durante scroll, con scroll interno del menú y móvil sin cambios.
- Ticket digital por entrada con identidad visual del evento, organizador, precio, pedido, estado y QR opaco `KXEVT:<ticket_token>`.
- Información visible sobre el rol de KOMBAX como plataforma tecnológica, cobro mediante Stripe para el organizador y canal de contacto del organizador.
- Dashboard de aforo: pagadas, reservadas, check-in, pendientes, reembolsadas, anuladas, disponibles e ingresos confirmados.
- Lector QR integrado en Events mediante cámara del navegador/PWA/Android (`BarcodeDetector`) con fallback manual.
- Check-in server-side transaccional con `FOR UPDATE`; el segundo lector simultáneo obtiene `already_used`.
- Estados de validación: válida, ya utilizada, reembolsada, anulada, otro evento e inválida.
- Equipo específico de acceso: gestión de entradas, control de acceso y taquilla. No concede permisos Stripe/bancarios.
- Auditoría de intentos de check-in sin almacenar el QR en claro (solo fingerprint SHA-256 para correlación operativa).

## QA obligatorio
1. Comprar 1, 2 y 4 entradas en Stripe TEST y verificar exactamente N tickets/QR.
2. Repetir webhook y confirmar que no se duplican entradas.
3. Escanear un QR válido y volver a escanearlo desde dos dispositivos.
4. Escanear QR de otro evento, reembolsado, anulado y un valor inventado.
5. Confirmar que un usuario `access_control` puede escanear pero no configurar Stripe ni el evento.
6. Confirmar que `box_office` puede ver ventas + acceso, y `ticketing_manager` ventas + acceso.
7. Verificar contactos del organizador, copy legal y coherencia antes/después del pago.
8. Scroll largo de Social/Events/Showcase en desktop: el sidebar debe permanecer visible; móvil mantiene drawer/bottom-nav.

## No realizado por esta migración
- No se despliega frontend a Netlify.
- No se hace push a GitHub.
- No se habilita un modo offline de check-in; en piloto el check-in requiere conexión para impedir duplicados entre dispositivos.
