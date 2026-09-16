# KOMBAX 20.110 R62.7 — Showcase Marketplace & Owner Control Center

Fecha: 11/09/2026
Estado: **QA READY**. No declarar producción pública.

## Showcase · Centro de vendedor
- Nuevo flujo único de alta: identidad KOMBAX → solicitud de vendedor → contrato/políticas → Stripe Connect → vendedor activo.
- Reutiliza la verificación de Club/Marca existente; no obliga a duplicar documentación ya validada.
- Nueva solicitud comercial con razón legal, NIF/CIF, país, domicilio registral, contacto de soporte, devoluciones, modalidades de entrega y declaraciones de cumplimiento.
- Estados auditables: `draft`, `submitted`, `under_review`, `needs_information`, `verified`, `limited`, `suspended`, `rejected`.
- Un producto solo puede activar venta directa cuando el vendedor está completamente listo.

## Contrato y políticas
- Documentos versionados con aceptación trazable: condiciones Marketplace, acuerdo de vendedor, protección del comprador y productos prohibidos.
- Los textos incluidos son **borradores operativos de QA** y tienen `legal_review_status=pending`.
- La compraventa queda planteada entre comprador y vendedor; KOMBAX presta infraestructura tecnológica y mantiene las obligaciones propias que legalmente correspondan.
- El vendedor asume las obligaciones sobre legalidad/autenticidad, descripción, precio/impuestos, stock, entrega, garantías, devoluciones y posventa.
- KOMBAX conserva facultades de moderación, retirada, limitación, solicitud de información y cooperación ante fraude/riesgo.

## Pagos
- Stripe Checkout alojado sigue siendo el formulario de pago; KOMBAX no almacena número de tarjeta ni CVC.
- Showcase usa Stripe Connect con cargos directos a la cuenta del vendedor.
- Comisión transaccional KOMBAX actual: **0**.
- Nuevo gate server-side R62.7 antes de crear el checkout: producto vendible + vendedor completamente activo + aceptación de condiciones del comprador.
- El Edge Function remoto `stripe-checkout` fue actualizado con este gate.

## Compradores
- Nuevo modelo de confianza por niveles: cuenta KOMBAX, pago verificado y verificación reforzada de identidad opcional.
- La identidad reforzada **no es requisito para una compra ordinaria**.
- Si se solicita voluntariamente/por riesgo, la documentación queda privada y revisable por Owner; no se expone en Showcase.

## Owner Control Center
- Navegación superior: Resumen, Analytics, Verificaciones, Showcase y Operaciones.
- Verificaciones separadas: identidades Club/Perfil, vendedores Marketplace y compradores reforzados.
- Analytics de Seller Center y Marketplace: proveedores, solicitudes, vendedores verificados/listos, Stripe listo, productos, pedidos, GMV de vendedores, compradores, reembolsos, incidencias y ratios porcentuales.
- GMV se presenta explícitamente como volumen de los vendedores, no como ingreso KOMBAX.
- Decisiones Owner dejan trazabilidad de estado, actor, fecha y nota.

## Backend / seguridad
- Nuevo esquema privado `kombax_marketplace` con 7 tablas.
- Acceso directo revocado a `anon` y `authenticated`; operaciones mediante RPCs controlados.
- RPCs `SECURITY DEFINER` con `search_path=''` y checks de gestión/Owner.
- Gate de checkout ejecutable únicamente por `service_role`.
- Índices de FK de esta fase cerrados tras Performance Advisor.

## Compatibilidad
- Discovery R62.6 preservado.
- Showcase R61, Stripe R62.x, Events/Tickets R62.5.x y el flujo de pedidos existentes se conservan.
- No se ha activado ningún vendedor ni producto comercial ficticio durante QA.
