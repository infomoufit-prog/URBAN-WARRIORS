# R62.5.2 · Matriz de agentes IA para QA

1. **Agente Stripe Checkout** — intenta alterar cantidad, precio, beneficiario y request_id; valida que servidor manda.
2. **Agente Webhook/Idempotencia** — repite eventos Stripe y confirma emisión exactamente una vez.
3. **Agente Aforo/Concurrencia** — fuerza compras simultáneas de las últimas plazas y busca sobreventa.
4. **Agente QR/Check-in** — QR válido, repetido, manipulado, reembolsado, anulado y de otro evento.
5. **Agente Carrera de acceso** — simula dos check-in concurrentes del mismo ticket; solo uno debe ser `valid`.
6. **Agente Permisos** — prueba event manager, ticketing_manager, access_control, box_office y usuario ajeno.
7. **Agente Multitenant** — intenta cruzar Club/Federación/Marca/organizador y eventos distintos.
8. **Agente Privacidad** — busca exposición de buyer email, ticket_token, QR, Stripe account o datos de otro evento.
9. **Agente Responsive/PWA** — sidebar desktop, móvil, cámara, cierre/reapertura del lector y fallback manual.
10. **Agente Regresión** — ejecuta suite completa y verifica que Showcase, Events, Connect, Android y navegación anterior permanecen estables.

Para cada agente registrar: escenario, identidad usada, pasos, resultado esperado, resultado observado, PASS/FAIL, evidencia y corrección si existe. Tras cualquier corrección repetir el caso y la regresión afectada.
