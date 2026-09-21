# Tap to Pay / NFC · fase nativa posterior

La app Android actual es un contenedor WebView/PWA y no incluye Stripe Terminal. Tap to Pay requiere SDK nativo, dispositivos compatibles, permisos y ciclo de conexión/ubicación/lector. Introducirlo en R61 aumentaría el riesgo de la release.

Puntos preparados:

- Connect identifica al club receptor.
- `payment_attempts` ofrece idempotencia y trazabilidad común.
- La cuota conserva el origen y referencia del pago.
- Webhooks son la fuente de verdad del resultado.

Fase 2 deberá añadir un módulo Android aislado con Stripe Terminal, endpoint server-side de connection tokens, selección de ubicación/lector, pruebas en dispositivos admitidos en España, reconciliación con `cuotas` y fallback a Checkout online. No se deben crear PaymentIntents ni connection tokens desde el cliente.
