# KOMBAX 20.059 · CHAT READ RECEIPTS — VALIDATION

Fecha: 2026-08-20
Base: `KOMBAX_Urban_Warriors_RC13_build_20059_OPEN_CHAT_AUTOSYNC`
Intervención: recibos de lectura del chat KOMBAX
Estado: CANDIDATA PARA VALIDACIÓN MANUAL · NO FREEZE FINAL

## Alcance implementado

- Los mensajes propios muestran `✓ Enviado` mientras `leido_en` está vacío.
- Cuando el destinatario abre la conversación y el backend marca el mensaje, el estado pasa a `✓✓ Leído`.
- El recibo se representa únicamente en mensajes propios.
- El texto visible permanece discreto y accesible (`title` + `aria-label`).
- El autosync existente refresca periódicamente los recibos de la página reciente sin recargar el historial completo.
- El cambio de `leido_en` actualiza el DOM del mensaje existente; no reconstruye la conversación ni mueve el scroll.
- El Contact Gate, chat ilimitado, paginación, bloqueo, cierre, marcado de lectura y reconexión de 20.059 permanecen intactos.

## Supabase

No se ha creado ninguna migración nueva ni se ha modificado esquema, RLS, grants o RPCs.
Se reutilizan los contratos ya desplegados:

- `kombax_social_contacto_mensajes.leido_en`
- `app_kombax_contact_mark_read_v067(uuid)`
- `app_kombax_contact_mensajes_v104(uuid,integer,integer,integer)`

Preflight live:

- `leido_en`: presente.
- RPC de marcado de lectura: presente.
- historial v104: presente.
- `authenticated`: puede ejecutar marcado de lectura.
- `anon`: no puede ejecutar marcado de lectura.

Prueba live transaccional:

1. Se insertó un mensaje QA temporal dentro de una transacción en una conversación aceptada.
2. Se simuló al destinatario autenticado.
3. `app_kombax_contact_mark_read_v067` marcó el mensaje.
4. `app_kombax_contact_mensajes_v104` devolvió `read_receipt_set=true`.
5. Se ejecutó `ROLLBACK`.
6. Verificación posterior: `qa_read_receipts_persisted = 0`.

## Regresiones automáticas

Nueva prueba: `scripts/test-kombax-20059-read-receipts.mjs`

Valida:

- estados `Enviado` / `Leído`;
- visibilidad solo para mensajes propios;
- refresco de recibos sobre página reciente;
- actualización de `leido_en` sin recarga total;
- conservación del marcado automático al abrir/recibir;
- estilos de interfaz;
- contrato v104 con timestamp de lectura.

Resultados:

- `npm test`: PASS.
- `npm run build`: PASS.
- test específico de recibos: PASS.

## Igualdad de superficies

Comparación SHA-256 independiente tras el build:

- `web`: 65 archivos.
- `dist`: 65 archivos.
- `android/app/src/main/assets/www`: 65 archivos.
- faltantes: 0.
- extras: 0.
- diferencias de hash: 0.
- Web tree SHA-256: `62376b1b4377df7b4271c9f2484a00a1d155ed0d62d27bcf7f4cc8769462a47f`.

## Android

Preflight Android: 4/5.

- applicationId estable: PASS.
- versionCode 20059: PASS.
- assets/www: PASS.
- Firebase: PASS.
- firma local: PENDIENTE por diseño del paquete (`android/keystore.properties` no se distribuye).

## Secret audit

- keystores / PKCS / PEM: 0.
- bloques de clave privada: 0.
- asignaciones largas de `service_role`: 0.

## Archivos modificados respecto a la candidata 20.059 anterior

- `web/js/modules/kombax-social.js`
- `web/css/kombax-premium.css`
- copias sincronizadas equivalentes en `dist/` y Android.
- `package.json`
- nuevo `scripts/test-kombax-20059-read-receipts.mjs`

No se modificaron migraciones Supabase ni contratos de seguridad.

## Validación manual pendiente antes de freeze

Probar con dos cuentas reales simultáneas:

1. A envía mensaje → debe mostrar `✓ Enviado`.
2. B recibe el mensaje sin abrir → A debe seguir viendo `✓ Enviado`.
3. B abre la conversación → A debe pasar a `✓✓ Leído` tras el autosync.
4. Repetir en navegador, PWA y APK.
5. Repetir con pérdida y recuperación de conexión.
6. Confirmar que el scroll no salta al cambiar solo el estado de lectura.

Esta intervención no convierte el autosync actual en WebSocket/Broadcast; mantiene la arquitectura 20.059 existente y añade el recibo de lectura sobre los contratos ya desplegados.
