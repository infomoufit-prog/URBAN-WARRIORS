# R62.5.2 · Checklist de estabilización QA

## Automatizado · completado
- [x] Suite completa `npm run build`.
- [x] R61 Payments + Showcase Commerce.
- [x] R62.4 Stripe Connect hardening.
- [x] R62.4 SQL integrity.
- [x] R62.5 Showcase + Events Ticketing.
- [x] R62.5.2 Ticket QR Access + Sticky Sidebar.
- [x] Sintaxis JS de repositorios y Events.
- [x] Hash idéntico web/dist/Android para archivos R62.5.2.
- [x] Escaneo de secretos Stripe sin valores `sk_live_`, `sk_test_` o `whsec_` reales.
- [x] Migración Supabase R62.5.2 aplicada.
- [x] Verificación remota final R62.5.2: PASS.
- [x] Ninguna RPC R62.5.2 ejecutable por `anon`.
- [x] Tablas privadas de personal/check-in sin SELECT directo para `authenticated`.
- [x] `SECURITY DEFINER` R62.5.2 con `search_path=''`.

## Manual / Stripe TEST · pendiente para estabilización
- [ ] Comprar 1 entrada y confirmar exactamente 1 ticket/QR.
- [ ] Comprar 2 y 4 entradas y confirmar exactamente N tickets/QR.
- [ ] Repetir webhook de pago y comprobar que no duplica tickets.
- [ ] Checkout cancelado y tarjeta rechazada no emiten entradas válidas.
- [ ] Reembolso invalida las entradas correspondientes.
- [ ] Escanear un QR válido desde PWA/Android real.
- [ ] Escanear el mismo QR simultáneamente con dos dispositivos: un único acceso válido.
- [ ] QR de otro evento devuelve `wrong_event` sin filtrar datos del otro ticket.
- [ ] QR reembolsado/anulado/inventado devuelve el estado correcto.
- [ ] `access_control` puede escanear pero no modificar Stripe ni el evento.
- [ ] `box_office`/`ticketing_manager` ven las operaciones previstas y nada más.
- [ ] Un miembro de acceso asignado puede localizar/abrir el evento según su visibilidad real.
- [ ] Sidebar permanece visible en scroll largo desktop; móvil no sufre regresión.
