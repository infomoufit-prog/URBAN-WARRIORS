# KOMBAX RC13 · Build 20.059

## Open Chat + Autosync

- Contact Gate preservado: motivo + solicitud + aceptación previa.
- Chat aceptado sin límite artificial de 20 mensajes y sin autocierre.
- `ordinal` de mensajes ampliado a integer y retirado el CHECK histórico <=20.
- RPC v104 para listado de conversaciones, historial paginado y mutación de red/contacto.
- Historial reciente primero + carga progresiva de mensajes anteriores.
- Autosincronización incremental mientras el chat está abierto, recuperación de conexión y retorno a primer plano.
- Enter envía / Shift+Enter introduce salto de línea.
- Contactar reutiliza hilo pendiente o aceptado cuando ya existe.
- Normas KOMBAX Social actualizadas a 1.3.0.
- Web/PWA/Android versionados en 20059.

No se declara todavía Realtime WebSocket/Broadcast; esta primera fase usa sincronización incremental automática.
