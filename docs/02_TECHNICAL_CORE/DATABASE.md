# Base de datos · KOMBAX RC13 build 20025

## Cadena conocida

| Migraciones | Dominio | Estado en esta entrega |
|---|---|---|
| 001–036 | núcleo Urban Warriors / RC13 recibido | estado heredado y documentado |
| 037 | notificaciones leídas | implementada local; Supabase real pendiente |
| 038 | archivo/papelera | implementada local; Supabase real pendiente |
| 039 | branding/temas | implementada local; Supabase real pendiente |
| 040 | puerta/contextos KOMBAX | implementada local; Supabase real pendiente |
| 041 | KOMBAX Social Alpha | implementada local; Supabase real pendiente |
| 042 | KOMBAX Showcase | implementada local; Supabase real pendiente |

## Reglas

- Migraciones incrementales y transaccionales.
- Preflight, verify, prueba transaccional y rollback por fase.
- RLS habilitado y acceso directo revocado en los nuevos dominios globales.
- Campos públicos explícitos; no `select *` hacia clientes en directorios globales.
- Mutaciones idempotentes con `app_mutation_requests`.
- Sin fixtures DEMO/carga en producción.

## Global frente a tenant

Los recursos operativos del club siguen delimitados por `club_id`. KOMBAX Social y Showcase son globales: enlazan sujetos públicos y verifican propietario, gestor, moderador o entitlement. No copian datos administrativos del tenant.

## 041 Social

Perfiles, publicaciones, likes, bloqueos, solicitudes de contacto, denuncias y auditoría son tablas independientes de Comunidad del Club. El contacto comprueba edad en vivo y exige 18 años a cualquier perfil personal. No existen tablas de seguidores, conversaciones o mensajes.

## 042 Showcase

Marcas, gestores, categorías y elementos informativos. URLs/galería requieren HTTPS; el precio es opcional/orientativo. No existen entidades de carrito, pedido, pago, stock, envío, devolución o checkout.

La secuencia operativa completa está en `SUPABASE_KOMBAX_RC13_20022_20025_RUNBOOK.md`.
