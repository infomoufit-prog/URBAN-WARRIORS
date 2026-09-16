# KOMBAX R63 — Matriz contractual y redline conceptual

## Arquitectura mínima objetivo
| Documento actual | Propósito | Acción R63 | Aceptación | Relación |
|---|---|---|---|---|
| Terms generales | cuenta/plataforma/software | KEEP + UPDATE | Sí, general | KOMBAX ↔ usuario |
| Privacy | tratamiento de datos | KEEP + UPDATE | Información/consentimiento cuando proceda | KOMBAX ↔ interesado |
| marketplace_terms | reglas Marketplace | MERGE/UPDATE como condiciones específicas Showcase | Sí antes de vender/comprar cuando proceda | KOMBAX ↔ profesional/usuario |
| seller_agreement | obligaciones vendedor | UPDATE; preferible anexo vendedor a Showcase | Sí para habilitar vendedor | KOMBAX ↔ vendedor |
| buyer_protection | información comprador | MERGE en checkout/condiciones; evitar consentimiento independiente innecesario | Acceso, no necesariamente click separado | vendedor ↔ comprador / plataforma informa |
| prohibited_products | política de producto | KEEP + UPDATE | vendedor reconoce al habilitar venta | KOMBAX ↔ vendedor |
| events_organizer_terms | organizador | UPDATE | Sí al habilitar Events comercial | KOMBAX ↔ organizador |
| events_ticketing_agreement | ticketing/pagos | MERGE como anexo/capacidad de organizer terms cuando sea viable | Sí al activar ticketing | KOMBAX ↔ organizador |

## Redline conceptual principal
1. **Edad comercial** — ADD: compras Showcase/tickets KOMBAX solo para perfiles identificados ≥18; no modifica reglas de cuenta 16–17.
2. **Merchant/organizador real** — KEEP/CLARIFY: vendedor u organizador celebra la operación; KOMBAX aporta infraestructura tecnológica.
3. **Stripe** — KEEP/CLARIFY: operación en connected account; no prometer custodia/reembolso KOMBAX si técnicamente no ocurre.
4. **Comisión** — KEEP: KOMBAX no aplica comisión porcentual de transacción en esta arquitectura; SaaS se cobra separadamente.
5. **Seguridad de productos** — ADD: datos de fabricante/responsable UE cuando corresponda, warnings y documentación por categoría; CE solo si aplica.
6. **Notice and action** — ADD: canal producto/evento, expediente, evidencia, decisión y restauración/revisión.
7. **Cancelación Events** — UPDATE: separar desistimiento ordinario, cancelación, aplazamiento, cambio sustancial e incidencias; no usar “sin devoluciones” como absoluto.
8. **Refund** — UPDATE: cancelación crea obligación/plan operativo pero R63 no mueve dinero silenciosamente; ejecución y reconciliación según connected account.
9. **Versionado** — ADD: documento, versión, effective date, hash, actor, timestamp y evidencia; no sobrescribir aceptación histórica.
10. **Responsabilidad** — REMOVE cualquier absoluto “KOMBAX no tiene responsabilidad alguna”; delimitar obligaciones de plataforma, vendedor y organizador.

## Documentos nuevos incluidos
Los ficheros de `docs/legal-r63/` son borradores consolidados para revisión jurídica y no se presentan como asesoramiento ni como “100 % legal”.
