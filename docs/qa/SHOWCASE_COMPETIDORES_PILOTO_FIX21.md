Migración aplicada en Supabase: competitor_pilot_showcase_capacity_fix21.

Las cinco plazas del grupo competitor-pilot-five-fix18 tienen capacidad de 15 publicaciones activas de catálogo en Showcase, sin contratar un plan. El beneficio se comprueba al consultar capacidad y se aplica automáticamente al registrarse los competidores autorizados. Se conserva cualquier capacidad superior existente.

La excepción requiere pertenecer a esas cinco plazas, perfil Competidor activo y verificado. Mantiene la gestión por identidad, los controles de contenido, revisión de productos y todos los requisitos comerciales para venta y cobro. No concede alta de vendedor ni cuenta Stripe.

Siete pruebas en Supabase real correctas: alta piloto automática; cuenta fuera del grupo sin catálogo gratuito; piloto con 15 plazas; guardar borrador; impedir producto sin revisión; publicar producto aprobado sin venta habilitada; retirar capacidad gratuita al suspender el perfil. Todo se revirtió, incluida la identidad creada, sin consumir plazas ni dejar publicaciones.

Advisors: sin cambios frente a la auditoría anterior. Seguridad mantiene 235 RLS sin políticas, 60 funciones definer anon, 640 authenticated y 1 aviso de contraseñas. Rendimiento mantiene 256 FK sin índice, 305 índices sin uso y 1 duplicado. Son avisos existentes pendientes de revisión global.

No se modifica frontend ni se requiere otro despliegue para este permiso. El ZIP FIX21 anterior permanece intacto. Conservar además el SQL adjunto en el repositorio cuando se actualice manualmente: esta migración posterior todavía no está incluida en ese ZIP. No ejecutar repetidamente el historial completo de migraciones.
