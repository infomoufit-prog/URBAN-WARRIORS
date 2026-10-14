# KOMBAX — Fase 5C (14 de octubre de 2026)

## Base
Se continúa desde el acumulativo 5B verificado (SHA-256: `990b36f464436c7b9d87ad2fd104a373c99e6f2feb548f431234d4efe8470fc1`). Se conservan las fases 0–5B, incluyendo R264 de finanzas, R265/R266 de ticketing y R268 de Showcase.

## Entregado en 5C

- Instagram: desde el panel de la identidad, nuevo botón para **subir un archivo JPEG y preparar publicación**, reutilizando el compositor KOMBAX Social, sin almacenamiento paralelo. También se mantiene la opción **elegir una publicación anterior**.
- Instagram: el compositor tiene una casilla para preparar la publicación externa, exige imagen nueva `image/jpeg`, publicación **pública**, identidad autorizada, crea el post en KOMBAX Social, y **después** abre una confirmación separada para Instagram. Si se cancela Instagram, el post en KOMBAX permanece. Los enlaces HTTPS pueden incluirse en el texto pero no se garantizan clicables en Instagram feed.
- Events: en checkout de categorías comercialmente habilitadas se muestra el **precio facial por unidad y total** según el catálogo leído de R266, número de plazas y puerta. La validación de stock, precio y elegibilidad sigue siendo responsabilidad del servidor, no del HTML.
- Events: nuevo diagnóstico R269 que informa al organizador de categorías, configuración del evento, habilitación comercial, contratos, verificación, normativa y Stripe Connect. **No activa ventas ni categorías**; no hay cambios en `checkout_enabled`.
- Tres migraciones del mismo paquete: `kombax_event_ticket_categories_preflight_r269`, `kombax_event_ticket_preflight_json_guard_r269b` y `kombax_event_ticket_preflight_seller_guard_r269c`, registradas en Supabase. Son funciones de diagnóstico, sin borrados de datos.
- Código sincronizado en `web`, `dist`, `android/app/src/main/assets/www`.

## Verificaciones
- 26/26 F5C estáticas/contratos y validación de URLs; 40/40 F5B; 28/28 Showcase; 94/94 navegación premium; 23/23 Meta mock; 8/8 transporte Meta mock.
- Node `--check` de los cuatro módulos modificados.
- Supabase: función R269 `SECURITY DEFINER`, no accesible a `anon`, acceso a `authenticated` limitado por control de propiedad de evento. Guard de JSON verificado.
- No se han enviado mensajes ni publicaciones a Instagram; no se han creado categorías, ventas, reembolsos ni QR reales. GitHub y Netlify sin cambios.

## Pendiente / bloqueos reales
1. **Instagram**: 0 conexiones, 0 publicaciones registradas. Se precisa conectar una cuenta profesional autorizada en `https://kombax.es`, revisar permisos y callbacks en Meta, autorizar una prueba de publicación real y completar validaciones OAuth/deautorización. API actual admite JPEG vinculada a post Social; no se ha certificado Stories/Reels ni imagen arbitraria sin post.
2. **Events VIP**: 0 categorías configuradas; no se ha ejecutado E2E Stripe/venta/QR/reembolso. RPC R265 guarda categorías sin activarlas; aún falta una activación comercial controlada por organizador y pruebas de los estados de reembolso. No afirmar ventas habilitadas.
3. **Federación**: backend v200 y frontend F5B conservados, pero sin licencia/equipo/club federativo real para probar permisos y exportaciones. No reportar E2E completado.
4. **Android**: frontend sincronizado; sin compilación APK/AAB ni prueba en dispositivo.
5. **Versión**: archivo R120 FIX22 y versión interna R118/build 20178 requieren reconciliación antes del próximo deploy del propietario.

## Prohibiciones respetadas
No GitHub push, no Netlify deploy, sin publicar Instagram real, sin cobros reales, sin activación comercial, sin modificación de productos o datos financieros existentes.
