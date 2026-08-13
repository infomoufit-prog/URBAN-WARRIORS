# Base de datos

## Regla operativa

Toda evolución parte de SQL022 RC10 y se aplica mediante migraciones ordenadas, no destructivas y con rollback conservador. La producción activa tiene aplicadas `023_restore_rc10_gateway_v166.sql` y `024_finance_annual_metrics.sql`.

## Migraciones de reconstrucción

| Migración | Estado | Cambios | Datos |
|---|---|---|---|
| 023 | Aplicada y validada | Recupera `app_mutate_v160` RC10 | No modifica registros |
| 024 | Aplicada; verificación 3/3 OK | Origen de cargo, índices y vistas financieras anuales | Conserva todo el histórico |
| 025 | Aplicada; verificación 2/2 OK | Validación de retirada, stock, entrega y cargo material | No borra pedidos existentes |
| 026 | Aplicada; rollback OK | Material dentro del motor común de avisos | Conserva historial |
| 027 | Aplicada; índice verificado | Índice multiclub para cursor estable de Comunidad | No modifica publicaciones |
| 028 | Aplicada; metadata/rollback 2/2 OK | MIME, dimensiones y peso de multimedia de Comunidad | Conserva paths y publicaciones |
| 029 | Preparada localmente | Vídeo 50 MB y paths de portadas automática/manual | Conserva multimedia existente |
| 030 | Preparada localmente | Aislamiento tenant, cierre DML e índices multiclub | No modifica datos de negocio |

## Finanzas

- `cuotas`: fuente de cargos; 024 añade `origen` (`cuota`, `material`, `otro`) y `origen_id`.
- `pagos`: fuente de cobros comunicados/validados.
- `recibos_cuota`: recibos trazables y anulables.
- `v_finanzas_detalle`: una fila por cargo con pagos validados agregados.
- `v_finanzas_metricas_mensuales` y `v_finanzas_metricas_anuales`: cifras derivadas, no redundantes.

Las vistas usan `security_invoker`; el aislamiento continúa dependiendo de RLS en `cuotas`, `pagos`, `socios` y `recibos_cuota`.

## Material

- `material_catalogo` y `material_variantes`: catálogo y stock por club.
- `material_pedidos`: la solicitud queda `pendiente_validacion`; conserva precio, validador, fecha y `cuota_id`.
- `material_entregas`: evidencia final relacionada con el pedido.
- `app_validar_retirada_material_v025`: transacción única con bloqueo de stock y cargo de origen `material`.
- `procesar_avisos_cobro`: tras 026 procesa cuota, material y futuros conceptos sin duplicar motores.

## Multimedia de Comunidad

- El binario permanece en el bucket privado `community-media` con path por club y perfil.
- `publicaciones_comunidad` conserva path y, desde 028, MIME, ancho, alto y bytes finales.
- El wrapper 028 delega primero en el gateway RC10 y completa únicamente los metadatos de la publicación recién autorizada.
- El wrapper 029 valida vídeo 1080p/50 MB y permite cambiar portada únicamente a Gestor/Coordinación.
- `notification-dispatch` elimina al caducar el archivo principal, la portada automática y la manual.

## Hardening multiclub

- `app_multiclub_audit_v030()` comprueba `club_id`, RLS, índice tenant y ausencia de DML cliente directo.
- `app_privilege_snapshot_v030` conserva los privilegios efectivos previos únicamente para rollback.
- Storage sigue siendo privado y los paths comienzan por `club_id/perfil_id`.

## Pendiente antes de despliegue

Ejecutar 024–030 en orden, validar resultados, comprobar planes/índices y ejecutar la matriz SELECT/INSERT/UPDATE/DELETE con roles reales.
