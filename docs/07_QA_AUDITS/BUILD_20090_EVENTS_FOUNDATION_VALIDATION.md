# Validación candidata · build 20.090

## Gates
- [x] Dominio público separado del dominio interno.
- [x] Migración aditiva; no se borra ni renombra ninguna tabla existente.
- [x] Lectura pública mediante RPC `security definer`; tabla sin SELECT directo.
- [x] UI con movimiento y `prefers-reduced-motion`.
- [x] Plantillas visuales locales/offline incluidas.
- [x] Feature flag propio.
- [ ] Migración 159 aplicada en Supabase de producción/piloto (acción operativa externa a este ZIP).
- [ ] Validación visual manual en APK/PWA real.

## Nota de despliegue
La UI degrada a un estado vacío elegante si el backend público de Eventos todavía no está aplicado. No afecta a `Mi Club > Eventos`.
