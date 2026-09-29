# R104.5 · Moufit Club Demo

- 2026-09-28: se concedió en el proyecto Supabase de KOMBAX un beneficio temporal Enterprise al club demo `11111111-1111-4111-8111-111111111111`. Vigencia hasta el 16 de noviembre de 2026, hora de Madrid. La suscripción Premium original no se modificó. El beneficio no constituye una suscripción facturable.
- Comprobación posterior: plan efectivo `enterprise`, catálogo Showcase ilimitado y Commerce permitido por plan. Una prueba transaccional del guardado de producto, metadatos y Commerce desactivado pasó y fue revertida.
- Frontend: el identificador de un producto nuevo ya no bloquea el envío del formulario; se genera a partir del nombre cuando queda vacío. Se sincronizó en web, dist y Android.
- Events: el plan efectivo permite publicar eventos sin límite mensual. La gestión de los eventos existentes está autorizada para el gestor probado. El servicio de Ticketing del evento demo está activo, pero la venta interna no está lista: Stripe Connect requiere acciones, la identidad del organizador no está verificada y el control de cumplimiento del evento no pasa. No se alteraron esos controles ni se realizó ningún cobro.
- Pruebas: comprobación sintáctica de Showcase, 13/13 controles existentes del Seller Center, construcción web/dist/Android y lecturas de estado en Supabase.
