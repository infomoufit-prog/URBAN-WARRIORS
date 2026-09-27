# KOMBAX R95 · Flujos de prepiloto

Base acumulativa: R94, build 20147. Entrega local: R95, build 20148. Fecha: 24 de septiembre de 2026.

## Aplicado

- La identidad Social del miembro activo ya no exige permisos del equipo del club. Se mantiene la edad mínima y la activación voluntaria; publicar como club sigue requiriendo permisos del equipo.
- Probado en la base de pruebas con una identidad real: el miembro puede actuar como miembro, no como club, y su identidad aparece en la lista propia.
- Los tres eventos de referencia del piloto vuelven a ser visibles en catálogo y enlace directo; las pruebas QA continúan ocultas. No se alteraron las fichas originales. Mantener al menos hasta el 8 de noviembre de 2026; el interclub del 14 de noviembre seguirá visible hasta celebrarse.
- Los tres productos demo de Urban Warriors pueden verse en el catálogo local de prepiloto. Conservan su condición de demostración y el contacto “Me interesa” puede usar la identidad del miembro adulto.
- Mi manual pasa a Ayuda rápida. Mantiene búsqueda y acceso a funciones, y remite a las Guías completas de Recursos. Se actualizaron las ocho traducciones de la navegación y de la presentación.
- Discovery permite declarar un peso competitivo exacto o un intervalo y buscar por peso exacto o por intervalo compatible. El dato también se muestra en la ficha pública cuando existe. El backend corrige el estado activo de los perfiles y limita el listado de competidores a verificados. El perfil no entra en Discovery sin activación voluntaria.

## Compra y Ticketing: preparación pendiente

No se ha activado un cobro de prueba ni marcado como pagado ningún pedido. La cuenta Connect del club del proyecto Supabase sigue action_required, con cargos y transferencias deshabilitados. El entorno Stripe de pruebas conectado a esta tarea no lista ninguna cuenta conectada y no reconoce la cuenta registrada en Supabase. Tampoco existe una solicitud de vendedor aprobada ni un derecho Commerce activo para el plan base del club. Los productos demo carecen de condiciones de entrega y devoluciones aptas para un checkout real.

Los dos eventos futuros conservan la venta externa de ejemplo, sin precio ni cupo internos. Sus enlaces externos apuntan a la portada KOMBAX y no se ofrecen como compra operativa. El gestor ya dispone del formulario Entradas y cobros para configurar modo KOMBAX, precio, cupo, límites, ventana, diseño y vista previa del ticket. El lector QR existe, pero no puede validarse con una entrada pagada hasta emitirla mediante checkout.

### Secuencia para la prueba completa

1. Vincular al proyecto la plataforma Stripe de pruebas correcta y completar la cuenta Connect del club/organizador; comprobar cargos, transferencias y tarjeta disponibles.
2. Completar y aprobar la activación del vendedor, sus condiciones y el derecho Commerce de prueba.
3. Crear una ficha de producto de prueba inequívoca con precio final, stock, condiciones de entrega/devolución y seguridad; habilitar venta directa.
4. Configurar un evento de prueba separado con Ticketing KOMBAX, precio y aforo. No convertir las fichas de referencia en ventas reales por accidente.
5. Ejecutar con miembro adulto: producto → carrito → Stripe test → webhook → pedido; evento → Stripe test → ticket QR → Mis entradas → lector → segundo escaneo rechazado. Probar también pago rechazado, aforo agotado y reembolso.

## Verificación

- Batería acumulativa pnpm test: correcta.
- Build: 612 archivos idénticos en web, dist y Android.
- Validación i18n: 1706 claves, ocho idiomas completos; auditoría de textos: cero pendientes.
- Migraciones R95 aplicadas y definición comprobada en el proyecto Supabase. La función de Social devuelve verdadero para miembro activo y falso para actuar como club.
- Pruebas de Discovery R62.6 y R76, Recursos R92 y R36: correctas.
- La prueba histórica R62.5 de ticketing exige un contrato antiguo ya reemplazado y falla incluso sin estos cambios; la batería acumulativa vigente pasa.
