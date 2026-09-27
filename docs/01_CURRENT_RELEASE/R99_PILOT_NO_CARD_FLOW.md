# KOMBAX 20151 · Solicitud piloto sin tarjeta

Base: R96 acumulativo, con los cambios R97 y R98 conservados. Esta fase prepara el registro de cuatro clubes piloto sin abrir la contratación general ni el trial público.

## Flujo implementado

1. En la solicitud de Perfil Club, el representante puede marcar **Solicito participar en el piloto**. Debe dejar vacío el plan comercial opcional. No se piden datos de tarjeta.
2. La solicitud y los documentos siguen el circuito normal de verificación de Club. La marca `pilot_requested` se guarda como dato privado de la solicitud; no otorga permisos.
3. Administración ve la cola de solicitudes piloto. Solo cuando la solicitud está verificada y tiene `club_id` puede asignar una plaza y un nivel Club, Premium o Enterprise. También puede asignar manualmente un club existente verificado.
4. La base limita las nuevas inscripciones a cuatro clubes mediante `pilot_club_slots`, configurable. La asignación es atómica frente a aprobaciones simultáneas.
5. La aprobación registra la entidad en `pilot_entities_r97` y un beneficio `PILOT_ACCESS` fechado del 1 de octubre al fin exclusivo del 15 de noviembre de 2026. No crea factura, suscripción pagada ni método de pago. El acceso comercial que consulta `active_plan_r64` usa ese beneficio durante su vigencia. El monedero único de Créditos IA reconoce la entidad piloto.
6. Al vencer el beneficio, la identidad, las membresías y los datos permanecen. Los beneficios Founder de los dos clubes seleccionados se asignan por separado; no se infieren de haber marcado la solicitud.

## Simulación de tarjeta

Los planes Club y Premium muestran una vista previa de la futura prueba de 15 días y de su renovación. La vista previa no recoge tarjeta ni persiste un estado «verificado». La contratación real y la renovación siguen cerradas hasta conectar Stripe Billing, comprobar impuestos, consentimiento, webhook y pruebas sandbox.

## Verificación realizada

- Migración R99 aplicada en Supabase. Configuración: cuatro plazas; cero clubes inscritos y cero beneficios `PILOT_ACCESS` antes de incorporar participantes.
- `anon` no puede ejecutar la cola ni la aprobación. Una llamada a la cola sin sesión administrativa devolvió `platform_admin_required`.
- Compilación web/dist/Android idéntica (612 archivos). Comprobación sintáctica de módulos modificados y regresión R88/R90/R92 superadas.

## Límites antes del piloto real

- Aún no se han probado la solicitud, revisión, aprobación y capacidades con las cuentas reales de los cuatro clubes.
- Algunas rutas históricas consultan suscripciones directamente en vez de `active_plan_r64`; hay que validarlas con un club piloto antes de afirmar que todas las funciones están habilitadas.
- Los textos nuevos del flujo piloto están en español; falta integrarlos en los otros idiomas de la aplicación.
- No se ha conectado la cuenta Stripe de KOMBAX. La simulación de tarjeta no es una verificación de pago.
