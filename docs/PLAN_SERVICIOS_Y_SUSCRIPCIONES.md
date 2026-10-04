# Plan de implementación: servicios y suscripciones verificadas

## Objetivo y reglas
Cuenta, perfil público, verificación, servicios y cobros son estados separados. Club, federación y marca pueden crear perfil gratuito sin tarjeta. Su prueba comercial exige verificación aprobada, plan y precio publicados y consentimiento de renovación en Checkout. Los cuatro clubes piloto mantienen su circuito autorizado sin tarjeta ni cobros.

Una cuenta general puede descubrir Servicios desde Mi Espacio. Para organizar se selecciona una identidad responsable propia y verificada. Profesional y competidor ya disponen de reglas de activación puntual en el servidor: no necesitan convertirse en club. Una membresía o un perfil espectador no concede automáticamente permisos de organizador. La autorización del servidor es la referencia, nunca el botón del frontend.

## Fases y criterios de aceptación
1. Identificar arquitectura y añadir acceso Servicios con navegación existente, textos traducidos y sin conceder permisos. Comparar aislamiento de clubes, cuentas sin perfil y profesionales. No presentar contratación simulada como activación real.
2. Unificar elegibilidad comercial de club, federación y marca: propietario/representante autorizado, verificación aprobada, plan compatible publicado, prueba única, exclusión del circuito piloto. Revisar las pruebas ya concedidas sin revocar accesos existentes por sorpresa. Sustituir RPC de activación directa por Checkout para nuevas pruebas comerciales.
3. Stripe Billing: catálogo de Product/Price por plan, Checkout en modo suscripción, 30 días, método de pago obligatorio, precio/frecuencia/impuestos/fecha de renovación y consentimiento claros. Customer Portal para cancelación y método de pago. No almacenar tarjeta o CVC. Sin precio configurado no hay Checkout. Verificar configuración fiscal antes de habilitar Stripe Tax.
4. Persistencia y webhooks: idempotencia, eventos duplicados y desordenados, activación solo por confirmación del servidor, trialing/active/past_due/canceled/unpaid; invoice.paid e invoice.payment_failed; recordatorio de fin de prueba, fecha de cancelación y trazabilidad. El retorno del navegador no concede servicios.
5. Eventos y seminarios: seleccionar organizador propio autorizado; separar crear/editar/publicar/promocionar/vender; preservar límites y permisos de cada evento. Conservar activaciones puntuales hasta que el Owner defina otra modalidad. No inventar una suscripción Profesional Pro.
6. Ticketing: autorización ligada a evento y aforo, Stripe Connect del organizador preparado para cobrar, sin confundir este alta de vendedor con la tarjeta que paga la suscripción de KOMBAX. Venta y emisión de entrada solo con pago confirmado. Verificar compras concurrentes, aforo, QR, acceso, cancelaciones y reembolsos.
7. QA: pruebas de autorización, no repetición de trial, webhooks autenticados, renovación/cancelación/fallo de pago mediante entorno Stripe de pruebas, regresión de los cuatro clubes piloto, navegación móvil/escritorio, compilación y archivos Android. No declarar prueba real de Stripe si no se ejecutó en un entorno conectado.
8. Entrega acumulativa: sincronizar fuente validada, auditar secretos, compilar web, revisar Android y generar ZIP con cuatro partes y reunificación comprobada. No push, despliegue ni cargos reales automáticos.

## Decisiones pendientes
- Precios oficiales y Stripe Price IDs de marca y federación y demás planes publicados; no inventar importes.
- Confirmado por el usuario: conservar activaciones puntuales por evento y ticketing según aforo, sin exigir suscripción de club.
- Contratación pública bloqueada actualmente por PUBLIC_PRICING_LOCKED=true durante el piloto; no desbloquearla globalmente para activar servicios comerciales.

## Estado verificado de partida
El trial actual se concede directamente desde Supabase sin Stripe. Marca no tiene el mismo botón de trial de Federación. El checkout existente cubre cuotas, pedidos y entradas, no suscripciones SaaS. Eventos acepta contextos profesionales y competidores, pero algunos mensajes aún hablan de Pro. Hay funciones de servidor de permisos y activaciones puntuales que deben respetarse y probarse.

## Estado de esta etapa
Implementados Servicios, filtros Owner, autorización puntual de vendedor/eventos y Billing verificado. Aplicadas cuatro migraciones y desplegadas dos funciones en Supabase. QA local y evidencia Stripe descritas en LEEME_KOMBAX_20178_FIX07.md. Pendientes precios publicados, credenciales/destino webhook, configuración fiscal/Portal, prueba de renovación real y compilación Android. No se declara operación comercial de producción certificada.

## Ampliaciones autorizadas
- Owner Social/Showcase: filtros por día/semana, perfil/vendedor, club vinculado y tipo (incluido competidor); consulta filtrada en servidor y acordeones de diez publicaciones.
- Mis servicios incluye actividad de vendedor, Showcase y e-commerce puntual para cuentas gratuitas y Club básico, previa verificación de vendedor y autorización comercial. Publicar catálogo no equivale a habilitar venta.
