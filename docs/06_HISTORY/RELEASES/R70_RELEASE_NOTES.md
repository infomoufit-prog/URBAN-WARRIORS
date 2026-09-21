# KOMBAX R70 · Release Notes

## Nuevo
- **Mi Showcase** aparece como subacceso persistente en la barra lateral, justo debajo de **KOMBAX Showcase**.
- **Mis Eventos** aparece como subacceso persistente en la barra lateral, justo debajo de **KOMBAX Events**.
- Los dos accesos son rutas directas privadas y no simples botones decorativos.
- El módulo público padre queda visualmente contextualizado cuando su centro privado está activo.

## Permisos
- Club: Dirección, Coordinación, Secretaría y Comunicación pueden recibir estos accesos.
- Usuarios sin capacidad de gestión no los reciben en la navegación.
- Las comprobaciones de autorización reales del Seller Center y del Centro de Eventos siguen en backend y no se han relajado.

## Sin cambios comerciales
- Club Básico: Showcase 15 productos; Commerce 12 €/30 días.
- Ticketing y publicación de Events conservan las tarifas R64.4.
- No se modifica Stripe Connect, fees, buyer age gate, planes ni SaaS Billing.

## Backend
- No hay nueva migración de base de datos en R70.
- `health` Supabase actualizado a build 20121.
