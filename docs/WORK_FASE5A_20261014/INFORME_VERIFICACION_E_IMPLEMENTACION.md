# KOMBAX — Fase 5A, Material y Showcase · 14-10-2026

**Base**: acumulativo fase 4, SHA-256 `d1a077d57feadad7a4f9cec6854c2ed519a377b877f4e1d9baafc1d61275c1d3`. Todos los archivos originales y fases 0–4 se conservan. No se usa GitHub `main` como fuente de reemplazo.

## Cambios nuevos verificados

1. `Mi Club → Material`: botón «Eliminar sin histórico» habilitado únicamente para gestores de material. Usa `repos.material.delete`, que invoca la operación `material.eliminar`: Supabase deniega el borrado si existen pedidos o entregas. Se conserva «Archivar» y NO se utiliza `material.eliminar_forzado` ni `repos.material.forceDelete` (que eliminarían historial).
2. El formulario no presenta una solicitud de material como si fuera una retirada ya realizada. Conserva `material.solicitar`, el estado pendiente, la observación y la validación posterior por personal del club.
3. Showcase: consulta «Me interesa» vinculada a cuenta autenticada y producto, sin exigir identidad Social independiente. Reutiliza RPC R58 existente; no crea tablas paralelas.
4. Compradores: «Mis consultas», histórico de mensajes y respuesta. Vendedores: «Consultas» desde navegación privada, bandeja por proveedor y respuesta. Las RPC de Supabase validan que solo cuenta titular o gestor autorizado puedan consultar el hilo.
5. Supabase R268: la eliminación de un producto con consultas R58, conversaciones Social anteriores, ventas, reseñas, movimientos de inventario, analítica asociada o informes de seguridad se convierte en RETIRADA para preservar el historial.
6. Copias de `web`, `dist` y `android/app/src/main/assets/www` sincronizadas para todos los archivos frontend modificados.

## Migraciones APLICADAS en el proyecto Supabase `poggsobhtutbuagjiydc`

- `20261014150538`: `kombax_showcase_preserve_inquiries_on_delete_r268`.
- `20261014151035`: `kombax_showcase_preserve_associated_history_r268b`.

Se incluyen archivos SQL reproducibles en `supabase/migrations/`. No se alteró el contenido de productos, pedidos o consultas existentes.

## Estado verificado (solo inspección, no pruebas de compra)

- Mi Material: 3 fichas, 6 pedidos.
- Showcase: 5 fichas, 0 consultas R58.
- Meta/Instagram: cuatro funciones Edge activas; 0 conexiones reales, 0 publicaciones. No está validado OAuth end-to-end ni publicación externa.
- Finanzas: `app_kombax_historical_finance_fix20` para históricos; `app_kombax_fee_void_r264` para anular cargos impagados sin pagos/recibos/Stripe, no para editar pagos consolidados. La antigüedad del socio se guarda en `socios.fecha_alta` y el contrato `app_kombax_member_batch_mutate_r120` utiliza el campo.
- Capacidades de otros perfiles: las comprobaciones de permisos residen en sus contextos y capacidades específicas; no se ha certificado E2E por identidad. Mi Federación tiene contrato de dashboard/capacidades, pero la base actual contiene cero licencias, relaciones y equipo federativo en tablas v200. La navegación premium se entregó en fase 4.

## Validación de código y regresiones

- 28/28 pruebas estáticas específicas de material, consultas, migración y sincronización.
- 52/52 pruebas de inventario y ciclo de vida R89.
- `node --check` para ambos módulos modificados: correcto.
- Las suites históricas R67 probadas muestran fallos previos por condiciones de Billing, versiones y material base no correspondiente. No atribuir esas fallas a este parche sin una comparación adicional.

## Pendiente de validación real

- Prueba con usuario comprador y vendedor reales/QA y confirmación de respuestas entrantes y salientes.
- Prueba negativa de lectura cruzada por otro vendedor, sin utilizar datos reales de terceros.
- Producto de prueba SIN histórico y otro CON histórico; comprobar eliminación vs retirada.
- Test de acceso en móvil, tablet, Android y PWA instalados.
- Verificar notificaciones push/email de consultas: este cambio ofrece bandeja, NO confirma avisos automáticos.
- No existe por este cambio un canal de «solo preguntas» para Mi Material: sus solicitudes siguen creando un pedido pendiente con campo `observaciones`.
- El paquete NO incluye modificaciones nuevas de OAuth/publicación Instagram ni tickets VIP en esta fase 5A. Siguen fases de desarrollo aparte, con backend R265/R266 ya auditado previamente.

## Política de cambios

No se ha hecho push GitHub ni deploy Netlify. No se han eliminado productos ni escrito consultas reales. El frontend requiere compilación/despliegue del propietario. Versionado interno conserva RC13 R118/build 20178 hasta reconciliarlo con R120 FIX22 antes de despliegue.
