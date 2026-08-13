# Matriz RLS de reconstrucción

Estado: base RC10 auditada; ampliación por recursos en curso. “Propio” incluye alumnado y familiares vinculados mediante las funciones existentes.

| Recurso / acción | Gestor | Coordinación | Secretaría | Alumno | Familia |
|---|---:|---:|---:|---:|---:|
| Cuotas SELECT | Club | Club | Club | Propio | Vinculados |
| Cuotas INSERT/UPDATE | Sí | según permiso compuesto | Sí | No | No |
| Pagos SELECT | Club | Club | Club | Propio | Vinculados |
| Pagos INSERT | Sí | según permiso | Sí | Propio | Vinculados |
| Pagos UPDATE validación | Sí | según permiso | Sí | No | No |
| Recibos SELECT | Club | Club | Club | Propio | Vinculados |
| Métricas SELECT | Datos visibles por RLS | Datos visibles por RLS | Datos visibles por RLS | Solo propios, no se muestran | Solo vinculados, no se muestran |
| Catálogo material SELECT | Club | Club | Club | Club | Club |
| Catálogo material INSERT/UPDATE | Sí | Sí compuesto | Sí | No | No |
| Pedido material SELECT | Club | Club | Club | Propio | Vinculados |
| Pedido material INSERT vía gateway | Sí | Sí compuesto | Sí | Propio | Vinculados |
| Validar retirada / stock / cargo | Sí | Sí compuesto | Sí | **No** | **No** |
| Entrega material SELECT | Club | Club | Club | Propio | Vinculados |
| Comunidad SELECT | Club | Club | Club | Club (publicado/propio) | Club (publicado/propio) |
| Comunidad INSERT vía gateway | Sí | Sí | Sí | Propio | Propio |
| Comunidad DELETE vía gateway | Club | Club | Club | Propio | Propio |
| Portada manual de vídeo | Sí | Sí | No | No | No |
| Multimedia Storage SELECT | Club | Club | Club | Club | Club |
| Multimedia Storage INSERT | Path propio | Path propio | Path propio | Path propio | Path propio |
| Multimedia Storage DELETE | Club | Club por rol encapsulado | Club | Path propio | Path propio |

La escritura directa de pedidos/entregas queda revocada; las mutaciones pasan por el gateway. La prueba definitiva se realizará en Supabase real después de aplicar cada migración y antes del deploy.

## Matriz CRUD explícita previa a pruebas reales

“Gateway” significa que el cliente no recibe DML directo y la operación vuelve a comprobar club, rol e idempotencia en `app_mutate_v160`.

| Recurso / acción | Gestor | Coordinación | Secretaría | Alumno | Familia |
|---|---|---|---|---|---|
| Comunicaciones SELECT | Club | Club | Club | Audiencia autorizada | Audiencia autorizada |
| Comunicaciones INSERT | Gateway | Gateway | No en RC10 | No | No |
| Comunicaciones UPDATE | Gateway | Gateway | No en RC10 | No | No |
| Comunicaciones DELETE | Gateway | Gateway | Gateway | No | No |
| Comunidad SELECT | Club | Club | Club | Publicadas + propias | Publicadas + propias |
| Comunidad INSERT | Gateway propio | Gateway propio | Gateway propio | Gateway propio | Gateway propio |
| Comunidad UPDATE/moderar | Gateway | Gateway | Gateway | No | No |
| Comunidad DELETE | Club | Club | Club | Propias | Propias |
| Multimedia SELECT | Club | Club | Club | Club | Club |
| Multimedia INSERT | Path propio | Path propio | Path propio | Path propio | Path propio |
| Multimedia UPDATE | No | No | No | No | No |
| Multimedia DELETE | Club | Club | Club | Path propio | Path propio |
| Cuotas/cargos SELECT | Club | Club | Club | Propios | Vinculados |
| Cuotas/cargos INSERT | Gateway | Gateway | Gateway | No | No |
| Cuotas/cargos UPDATE | Gateway | Gateway | Gateway | No | No |
| Cuotas/cargos DELETE | No; histórico | No; histórico | No; histórico | No | No |
| Pagos SELECT | Club | Club | Club | Propios | Vinculados |
| Pagos INSERT | Gateway | Gateway | Gateway | Comunicar propio | Comunicar vinculados |
| Pagos UPDATE/validar | Gateway | Gateway | Gateway | No | No |
| Pagos DELETE | No; trazabilidad | No; trazabilidad | No; trazabilidad | No | No |
| Catálogo material SELECT | Club | Club | Club | Club | Club |
| Catálogo material INSERT | Gateway | Gateway | Gateway | No | No |
| Catálogo material UPDATE | Gateway | Gateway | Gateway | No | No |
| Catálogo material DELETE | Gateway | Gateway | Gateway | No | No |
| Pedidos material SELECT | Club | Club | Club | Propios | Vinculados |
| Pedidos material INSERT | Gateway | Gateway | Gateway | Solicitud propia | Solicitud vinculada |
| Pedidos material UPDATE/validar | Gateway | Gateway | Gateway | No | No |
| Pedidos material DELETE | No; ciclo de estado | No; ciclo de estado | No; ciclo de estado | No | No |
| Perfiles SELECT | Equipo autorizado | Equipo autorizado | Equipo autorizado | Propio | Propio |
| Perfiles INSERT | Alta gobernada | No | No | Alta gobernada | Alta gobernada |
| Perfiles UPDATE | Propio/gateway | Propio/gateway | Propio/gateway | Propio/gateway | Propio/gateway |
| Perfiles DELETE | No | No | No | No | No |

La migración 030 cierra DML directo para estos recursos. Las celdas anteriores son el contrato esperado; todavía deben comprobarse con sesiones reales de cada rol.
