# KOMBAX R69 · Checklist QA para Work / piloto

## Objetivo

Validar que **Gestionar evento** y **Centro del evento** sean dos capas complementarias y que Ticketing desbloquee únicamente las operaciones que le corresponden.

## Personas / contextos mínimos

1. Club Básico con permisos de dirección.
2. Club Premium.
3. Club Enterprise.
4. Marca autorizada como organizador.
5. Gestor invitado de evento con `puede_gestionar` aceptado.
6. Usuario sin permisos de gestión.

## Mis Eventos

- Verificar botón **Mis Eventos** para organizadores autorizados.
- Verificar ausencia para cuentas sin capacidad de organizar.
- Confirmar que aparecen borradores, privados, publicados, finalizados y cancelados gestionables.
- Confirmar que no aparece ningún evento ajeno.
- Probar tarjetas en escritorio y móvil.
- Abrir **Centro del evento**, **Gestionar evento** y **Ver ficha** desde la misma tarjeta.

## Escenario A · evento sin Ticketing

- Publicar o mantener borrador según el caso.
- Abrir Centro del evento.
- Ver estadísticas básicas de publicación.
- Confirmar que Entradas, Asistentes, QR, Finanzas, Reembolsos, Comunicaciones, Historial y Equipo aparecen visibles pero bloqueados.
- Pulsar herramienta bloqueada y confirmar que dirige al flujo de activación Ticketing.
- Confirmar que el evento puede editarse y promocionarse sin Ticketing.

## Escenario B · Ticketing solicitado/no activo

- Solicitar Ticketing para el evento.
- Ver estado de servicio y precio/capacidad correctos.
- Confirmar que no se habilitan ventas prematuramente.
- Ver estados separados de Configuración, Condiciones y Stripe.

## Escenario C · Ticketing activo con activación incompleta

- Habilitar servicio/configuración pero dejar, de forma controlada, contratos o Stripe incompletos.
- Confirmar que Centro del evento indica **Activación incompleta**.
- Confirmar que checkout real no queda disponible antes de completar las condiciones.

## Escenario D · Ticketing completamente operativo

- Validar venta test Stripe de entrada.
- Confirmar incremento de entradas pagadas y facturación.
- Abrir **Entradas y ventas**.
- Abrir **Asistentes** y localizar comprador/pedido.
- Escanear QR válido.
- Confirmar check-in e historial.
- Intentar segundo uso del mismo QR y verificar bloqueo.
- Validar entrada anulada/reembolsada.
- Revisar finanzas y saldo/contexto Stripe.
- Ejecutar reembolso parcial/total controlado y confirmar invalidación exacta de QR.
- Revisar comunicaciones transaccionales.

## Estadísticas

- Validar vistas 30 días.
- Validar personas siguiendo el evento.
- Con Ticketing activo, validar checkout starts, compras, pagadas, usadas, ocupación e ingresos.
- Confirmar que BI Enterprise sigue bloqueado para planes no Enterprise y no sustituye las estadísticas básicas.

## Precios / derechos

Confirmar sin cambios:

- Publicación: 5/8/12/18 € para 7/15/30/60 días.
- Destacar: 3/5/8 € para 7/15/30 días.
- Ticketing: 10/15/25/45/75 € por tramos ≤50/100/200/500/1000.
- >1000: personalizado.
- Buyer fee fija: 0 €.
- Fee plataforma: 1,5 % no Enterprise / 0 % Enterprise.
- Enterprise: Ticketing incluido.

## Regresión Showcase R68

- Club Básico ve Mi Showcase.
- Puede activar cuenta vendedor sin Commerce.
- Mantiene 15 productos.
- Commerce temporal sigue siendo 12 €/30 días.
- Pedidos/finanzas/stock operativo continúan bloqueados hasta Commerce.

## Android

- Añadir `android/keystore.properties` local.
- Ejecutar preflight 5/5.
- Compilar APK debug y release firmada.
- Compilar AAB.
- Instalar en dispositivo Android y probar safe areas, back/close, Mis Eventos, Centro del evento, scanner QR y rotación/orientación.

## Gate de salida

No pasar a piloto si existe P0/P1, fuga de eventos ajenos, activación prematura de checkout, QR reutilizable, incoherencia financiera o pérdida de funciones R68.

Para lanzamiento público siguen pendientes además revisión legal final, hardening global de Supabase/Auth, QA manual autenticada, Stripe E2E y autorización explícita de despliegue.
