# KOMBAX RC13 build 20.087 — Plan de intervención Finance Explorer + Stability

## Objetivo
Cerrar las regresiones observadas durante la validación real de Finanzas Premium y preparar una experiencia escalable para clubes con cientos o miles de movimientos, sin romper trazabilidad contable ni histórico.

## Bloques implementados

### 1. Explorador financiero
- Sustituye los listados largos por navegación por bloques de 20 registros (máximo 50 por petición).
- Disponible para Cargos, Pagos, Recibos e Informes.
- Búsqueda textual, estado, ámbito Activos/Archivados/Papelera y paginación.
- Conserva filtros financieros de año, mes, alumno, grupo, disciplina, categoría, estado, método y antigüedad en Pagos/Recibos.
- Resumen conserva solo una muestra reciente y deriva al explorador para el histórico.
- Los gráficos/KPIs siguen calculándose sobre la verdad financiera completa: archivar no altera contabilidad.

### 2. Validaciones preventivas
- Bloqueo de validación si una cuota ya está cubierta.
- Bloqueo si un pago supera el saldo pendiente.
- Bloqueo de pagos sobre cuotas anuladas/exentas.
- Bloqueo de importes <= 0.
- Detección de pago prácticamente idéntico en menos de 2 minutos.
- Detección de cargo manual prácticamente idéntico por destinatario en menos de 2 minutos.
- Los pagos incompatibles devuelven `can_validate=false` y motivo humano antes de mostrar la acción.

### 3. Integridad financiera
Nuevo RPC `app_finance_v2_integrity_v155` para detectar:
- sobrepagos;
- cuotas pagadas con pagos pendientes;
- pagos pendientes superiores al saldo restante;
- cuota pagada sin recibo;
- recibo emitido antes de completar pago;
- estado de cuota incoherente con pagos;
- snapshot de informe sin PDF;
- PDF registrado pero ausente de Storage.

### 4. Archivo y papelera segura
- Estados `active`, `archived`, `trash` para cuota, pago, recibo e informe.
- Motivo obligatorio para archivar o enviar a papelera.
- Restauración posible desde Archivo/Papelera.
- Las acciones quedan registradas en auditoría.
- No se hace borrado físico silencioso de registros contables: la trazabilidad se conserva.

### 5. Mensajes de error
Se sustituyen errores genéricos conocidos por mensajes de dominio para cuota ya pagada, saldo excedido, doble pago, pago ya revisado, cargo duplicado, cuota cerrada, importe inválido y motivo de archivo/papelera requerido.

### 6. Informes PDF
- Se conserva el generador PDF con branding del club, KPIs, histograma, antigüedad de deuda y tabla.
- Se mantiene CORS compatible con navegador/PWA (`Prefer`).
- Se conserva el fix del cálculo de fin de mes (`interval '1 month' - interval '1 day'`).

## Política de datos sensibles
Archivar o enviar a papelera es una acción de presentación/retención, no una modificación de los importes ni una eliminación física de la evidencia contable. Los documentos financieros sensibles deben conservar trazabilidad y auditoría salvo un flujo legal de borrado específicamente diseñado para ello.

## Gate de aceptación
- Regresión RC13 completa: PASS.
- Legal release gate: PASS.
- `web = dist = Android`: PASS.
- Preflight Android: 4/5; firma local pendiente por diseño.
- Auditoría productiva: 0 bloqueantes; avisos conocidos documentados.
