# R62.7 · Implementación y QA

## Resultado
R62.7 convierte la capacidad de compra ya existente en un Marketplace gobernado por un **Seller Center**, políticas versionadas, buyer trust y un Owner Control Center específico.

## Supabase remoto
Proyecto: `poggsobhtutbuagjiydc`

Migraciones aplicadas:
- `kombax_r627_showcase_marketplace_owner`
- `kombax_r627_marketplace_fk_indexes`

Edge Function actualizado:
- `stripe-checkout` (JWT requerido), con `app_showcase_checkout_gate_r627` previo a la preparación del pago Showcase.

## Regla de habilitación de venta
`seller_ready_r627(provider)` exige simultáneamente:
1. Proveedor Showcase KOMBAX verificado y publicado.
2. Solicitud específica de vendedor aprobada por Owner.
3. Todas las políticas vigentes obligatorias de vendedor aceptadas.
4. Stripe Connect `active`, `charges_enabled=true`, `payouts_enabled=true`.

El frontend y el backend vuelven a validar ese estado. Una suspensión posterior impide nuevas compras aunque una ficha permaneciera publicada.

## Comprador
La compra ordinaria requiere cuenta autenticada y aceptación de las condiciones vigentes. La verificación documental reforzada es opcional/risk-based y está separada del pago. Stripe gestiona los datos de tarjeta.

## Contratos/políticas
Los cuatro textos incluidos están marcados como `1.0-qa` y `legal_review_status=pending`. **No deben considerarse asesoramiento jurídico ni textos definitivos para producción pública.** Antes del go-live deben ser revisados/adaptados por asesoría jurídica para España/UE, fiscalidad, consumo, DSA, privacidad y categorías de producto realmente permitidas.

## QA ejecutado
- Regresión completa `npm run test:20110:r62.7`: PASS.
- Regresión específica R62.4 tras mantener compatibilidad de `connectStatus`: PASS.
- Security Advisor ejecutado: conserva avisos históricos; no declarar advisor global limpio.
- Performance Advisor: inicialmente 192 FKs sin índice; R62.7 añadió 8 detectadas. Se añadieron sus índices y el total bajó a 184; ya no aparecen FKs sin índice del esquema `kombax_marketplace`.
- Permanecen avisos históricos de rendimiento, incluido un índice financiero duplicado.

## Estado remoto deliberado
No se crearon solicitudes, aceptaciones ni compradores ficticios:
- Seller applications QA: 0.
- Buyer identity requests QA: 0.
- Policy acceptances QA: 0.

El proveedor demo existente sigue sin estar `seller_ready`; sus productos permanecen sin `commerce_enabled`. La implementación no activa comercio real automáticamente.

## Pendientes antes de producción pública
- Revisión jurídica definitiva y versionado de textos aprobados.
- QA autenticada manual del Seller Center con un Club/Marca real de prueba.
- Stripe TEST end-to-end: onboarding Connect, compra, webhook, stock, pedido, reembolso/disputa e incidencia.
- QA de documentos privados de comprador y revisión Owner.
- QA móvil/PWA/Android del nuevo Seller Center y Owner.
- Resolver los gates generales de producción/piloto que siguen pendientes fuera de R62.7.

## No realizado
- No se ha desplegado el frontend a Netlify.
- No se ha hecho push a GitHub.
- No se ha publicado APK/AAB ni Google Play.
- No se ha hecho una compra Stripe TEST real en esta fase.
