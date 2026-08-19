# KOMBAX RC13 · BUILD 20029 · INFORME DE IMPLEMENTACIÓN

Fecha: 2026-08-17
Base: build 20028 IMPLEMENTED
Objetivo: cerrar bloqueos funcionales detectados en QA local antes de aplicar Supabase 051–056.

## 1. Alcance implementado

### KOMBAX Social
- Compositor de texto visible directamente en el feed.
- Publicación rápida de texto como identidad activa.
- Se mantiene el publicador completo con foto/vídeo y reutilización desde álbum.
- Feed con paginación progresiva mediante `IntersectionObserver` y botón manual de respaldo.
- Sentinel de carga y protección frente a dobles cargas.
- El feed diferencia explícitamente KOMBAX Social público de Comunidad interna del Club.

### Showcase
- Alta/edición de fichas mantiene estados borrador/publicado/archivado.
- Subida directa desde dispositivo de imagen principal y hasta 3 imágenes de galería.
- Optimización cliente de imagen y Storage segmentado por usuario/Showcase/proveedor.
- Políticas Storage 054 para `insert` y `delete` ligadas al gestor autorizado del espacio.
- Rollback 054 retira también dichas políticas.
- CTA existentes conservados: información, contacto, tienda/web, dónde encontrar, guardar y compartir.
- No se introduce carrito, checkout, pedido, pago, stock transaccional ni logística.

### Flujo Club / Comunidad / KOMBAX
- Comunidad del Club se presenta como espacio interno.
- Añadido acceso explícito `Ir a KOMBAX Social`.
- El Hub KOMBAX del Club separa Comunidad interna y Social público.
- Antes de publicar en Comunidad se muestra el destino interno.

### Visual
- Paleta KOMBAX actualizada a rojo sangre:
  - `--kx-red: #c9001b`
  - `--kx-red-deep: #65000d`
  - `--kx-red-hot: #ff1235`
- Microanimaciones de entrada en feed y Showcase.
- Acento vertical rojo en publicaciones.
- Animaciones respetan `prefers-reduced-motion` existente.

## 2. Backend afectado

No se añaden nuevas migraciones después de 056. Como 051–056 todavía no se han aplicado al remoto, se actualiza **054_kombax_showcase_actions.sql** para incluir las políticas Storage necesarias para las imágenes de Showcase.

Por tanto, al instalar 051–056 en Supabase se debe usar **el 054 incluido en este build 20029**, no una copia anterior del build 20028.

Verify 054 comprueba ahora también:
- `upload_policy_ok`
- `delete_policy_ok`

Rollback 054 elimina ambas políticas.

## 3. Versionado
- Web build: 20029.
- Service Worker/cache: 20029.
- Android `versionCode`: 20029.
- Android `applicationId`: `com.urbanwarriors.app` sin cambios.

## 4. Validación ejecutada

### Regresión
`npm test`: PASS.

Incluye toda la suite histórica RC13, los gates 20022–20028 y la nueva suite:
`scripts/test-kombax-20029-social-showcase.mjs`.

### Build
`npm run build`: PASS.

Resultado:
`70 archivos · web = dist = Android`.

### Sintaxis
- Todos los módulos `web/js/**/*.js`: `node --check` PASS.
- SQL 051–056: transacción/COMMIT, delimitadores `$$` y conflicto `position`: PASS.

### Smoke local
- Servidor local: `http://127.0.0.1:4173`
- HTTP 200.
- Assets cargados con `?v=20029`.

### Android preflight
3/5 preparado:
- OK applicationId.
- OK versionCode 20029.
- OK assets embebidos.
- PENDIENTE `google-services.json` real.
- PENDIENTE `keystore.properties`/JKS local.

Los dos pendientes son secretos locales intencionadamente excluidos del paquete.

### Secretos
No se incluyen `.env`, `google-services.json`, `keystore.properties`, `.jks` ni `.keystore`.

## 5. Estado real

Código 20029: implementado y estáticamente validado.
Supabase remoto: sigue certificado estructuralmente hasta 050.
Supabase 051–056: pendiente de aplicar/verificar/testear en remoto.
QA funcional real de Social/Showcase: debe realizarse después de aplicar 051–056, en local contra el Supabase real.

No declarar todavía producción/Google Play lista.
