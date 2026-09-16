# KOMBAX R72 · Auditoría previa de arquitectura comercial, reputación y comunidad

Fecha: 2026-09-14
Base auditada: R71 / build 20122
Objetivo: freeze candidate acumulativo para piloto controlado.

## 1. Hallazgos comerciales
- Fuente UI fallback: `web/js/core/commercial-pricing.js`.
- Fuente backend: `kombax_commercial.plan_pricing_r64` + `runtime_config_r64`.
- Límites vigentes: Club 15, Premium 25, Enterprise ilimitado; Brand Start 25, Brand Growth 100, Brand Enterprise ilimitado.
- Club básico Commerce: 12 EUR / 30 días renovable.
- Los límites actuales son rígidos al publicar: `app_kombax_showcase_item_guard_v045` bloquea cuando se alcanza la capacidad.
- No existe un add-on acumulable de catálogo.

## 2. Hallazgos de ciclo de vida de producto
- Estados actuales: borrador/publicado/archivado/oculto.
- Archivar ya conserva la ficha.
- La operación `kombax.showcase.elemento.eliminar` realiza borrado físico y posteriormente el cliente elimina medios propios.
- Esto es incompatible con reputación, pedidos y referencias persistentes una vez existan reseñas.

## 3. Pedidos y verificación de compra
- `kombax_payments.showcase_orders` contiene comprador, estado, entrega y vendedor.
- `kombax_payments.showcase_order_items` enlaza `product_id`.
- Puede verificarse una reseña con compra real, priorizando pedido `delivered` del mismo usuario/producto.

## 4. Tickets y verificación de asistencia
- `kombax_payments.event_ticket_orders` enlaza comprador y evento.
- `kombax_payments.event_tickets` contiene `holder_user_id`, `status`, `used_at` y `used_by`.
- Es posible identificar de forma autoritativa un asistente verificado mediante ticket utilizado.

## 5. Moderación y contenido
- KOMBAX ya dispone de patrones de moderación/reportes en Social y compliance marketplace.
- R72 debe reutilizar el patrón de permisos y trazabilidad, evitando permitir a vendedor/organizador borrar críticas legítimas.

## 6. UI existente
- Mi Showcase ya dispone de Centro de vendedor, productos, estadísticas, pedidos, stock, finanzas, comunicaciones y BI.
- Mis Eventos ya dispone de Centro del evento con operaciones, Ticketing, QR, asistentes, finanzas y comunicaciones.
- R71 incorpora acordeones laterales de Showcase y Events; deben preservarse.

## 7. Legal activo
- `web/terms.html`, `web/privacy.html`, `web/js/modules/help-legal.js` son superficies legales/informativas activas.
- `kombax_marketplace.policy_documents` contiene políticas Marketplace QA.
- `kombax_commercial.event_contract_documents` contiene condiciones Events/Ticketing QA.
- Los documentos siguen requiriendo revisión jurídica antes del lanzamiento público.

## 8. Riesgos principales
1. Destruir referencias con pedidos/reseñas mediante borrado físico.
2. Que expiración de bloques de catálogo borre productos o reputación.
3. Duplicar sistemas de comentarios y moderación.
4. Permitir reseñas falsas marcadas como verificadas.
5. Permitir a vendedor/organizador censurar valoraciones legítimas.
6. Exponer tablas privadas directamente por Data API.
7. Romper R71 navegación/planes/Commerce/Ticketing.

## 9. Decisiones R72
- Los límites pasan a ser **capacidad incluida**, ampliable en bloques +25.
- Add-on: +25 productos, 8 EUR / 30 días, renovable y acumulable.
- Enterprise permanece ilimitado.
- `archivado` libera slot y conserva historia.
- `eliminar` se convierte en borrado seguro: físico solo sin historial; con historial pasa a `retirado`.
- Se añade `fuera_capacidad` para referencias que deben preservarse sin ocupar visibilidad activa.
- Reseñas Showcase: 1–5 estrellas, texto, fotos, compra verificada, respuesta vendedor, reporte.
- Events: comentarios/respuestas, media, valoración, distintivo asistencia verificada, reportes.
- Tablas nuevas en esquema privado `kombax_reputation`, sin acceso directo anon/authenticated.
