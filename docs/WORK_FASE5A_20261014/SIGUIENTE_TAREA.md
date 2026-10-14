# Próximo punto de continuación

**Base obligatoria:** ZIP completo acumulativo FASE5A (a partir de FASE4, sin rebase en `main`).

1. Validar E2E de solicitudes de «Me interesa» comprador/vendedor con cuentas de prueba autorizadas. Comprobar respuesta, visibilidad, ACL y notificaciones. Evitar duplicar canales entre Social y Showcase; este hito usa consultas R58 y conserva conversaciones Social antiguas por separado.
2. Auditar y terminar Mi Federación Premium, comprobando datos reales, roles y RLS. Base v200 con 0 relaciones/federados licenciados/equipo actualmente, por lo que no existe prueba real de operaciones.
3. Continuar Meta/Instagram: conectar una cuenta profesional real autorizada, probar OAuth, elegir/subir imagen, vincular post existente y manejar enlaces (las URLs en Instagram feed no suelen ser clicables), publicar Social y preparar Events/Showcase. Nunca publicar contenido real sin consentimiento explícito.
4. Continuar categorías General/VIP de Events: comprobar reservas, precio por categoría, cobro Stripe, QR y reembolsos. No activar ventas sin pruebas end-to-end. Supabase R265/R266 ya existe; no recrearlo.
5. Valorar un flujo separado de «solo consulta» para material del club. Actual `material.solicitar` crea un pedido pendiente con observaciones; no es un buzón de preguntas.
6. QA, corregir fallos, preparar nuevo ZIP completo acumulativo en partes con SHA-256. Prohibido push GitHub y despliegue Netlify salvo autorización.
