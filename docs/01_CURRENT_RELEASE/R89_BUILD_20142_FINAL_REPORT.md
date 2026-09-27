# KOMBAX R89 · build 20142 · Pre-piloto acumulativo

## Estado

- Release: `2.0.0-rc.13-r89-inventory-lifecycle`
- Build web/PWA/Android: `20142`
- Base acumulativa anterior: R88 build 20141.
- Resultado: R89 acumulativo; no reconstruido desde versiones anteriores.
- Supabase live: migración `20260921212710_kombax_r89_inventory_lifecycle_events_sidebar` aplicada.
- Health Edge Function: ACTIVE v36, build 20142.
- No se ejecutaron cobros reales durante QA.

## Alcance implementado

### Mi Club · Materiales

Se mantiene el catálogo existente y se amplía con control económico de inventario:

- coste medio de compra;
- precio de venta;
- stock y stock mínimo;
- proveedor opcional;
- reposiciones/compras con actualización del coste medio ponderado;
- ajustes manuales;
- consumo interno;
- pérdidas/roturas;
- devoluciones;
- ledger de movimientos;
- snapshot de coste y margen en cada retirada/venta validada.

No se inventan costes históricos. Los campos nuevos permanecen nulos hasta registrar un coste real.

### Mi Showcase · Stock

El inventario existente se amplía sin crear un segundo catálogo:

- coste medio de compra;
- precio de venta;
- proveedor;
- stock mínimo;
- compras/reposiciones;
- ajustes, consumo, pérdidas y devoluciones;
- margen realizado en ventas futuras mediante snapshot del coste disponible en el momento de la venta.

### Finanzas Premium · Stock y materiales

Nueva lectura económica transversal sobre la misma fuente operativa:

- unidades actuales;
- valor de inventario a coste;
- valor potencial de venta;
- compras;
- ventas;
- margen realizado;
- coste de pérdidas;
- movimientos solicitados por bloques de 10.

Club y Showcase permanecen aislados por contexto financiero/identidad.

### Mi Club · Eventos

Se amplía la gestión privada manteniendo la arquitectura existente:

- detalle de fecha, hora inicio/fin y ubicación;
- historial de comunicaciones vinculadas al evento;
- comunicaciones paginadas 10 a 10;
- estado de conexión con KOMBAX Events público;
- conexión privada↔pública existente preservada;
- políticas de publicación selectiva existentes preservadas: general, horario, ubicación, categorías, participantes, fight card, pesaje, resultados, álbum y highlights.

No se ha creado un chat paralelo. Las comunicaciones del evento reutilizan el motor de Comunicaciones del club.

### Ciclo de vida / eliminación

Patrón común: `activo → archivado → papelera → restauración (30 días) → eliminación definitiva`, con previsualización de dependencias.

En R89:

- Materiales deja de usar borrado rápido destructivo para limpiar catálogo;
- Eventos privados pueden archivarse y moverse a papelera;
- eliminación definitiva de un evento se bloquea si existen participantes, combates, comunicaciones o conexión con KOMBAX Events;
- Materiales con pedidos/entregas preservan histórico;
- documentos y publicaciones mantienen el tratamiento de Storage ya existente;
- pagos, cuotas, pedidos, tickets, reembolsos y otros históricos financieros no se convierten en borrado libre.

El objetivo es reducir saturación visual sin destruir trazabilidad financiera, deportiva o legal.

### Listados y saturación

Las superficies R89 de archivo/papelera, movimientos financieros de inventario y comunicaciones de evento usan bloques de 10 registros y `Cargar 10 más` cuando existen resultados adicionales.

### Sidebar PC

Se corrigió la causa estructural detectada: rutas privadas de Federación/operaciones profesionales reemplazaban el `#app` completo y desmontaban el menú lateral. Ahora usan `setPrivateViewHtml()` y renderizan en `#main-view` cuando el shell privado está montado.

El contenido central puede cambiar/cargar/fallar sin desmontar la sidebar.

## Supabase y seguridad

- Schema privado `kombax_inventory` para ledger de stock Club.
- RLS activo en el ledger privado.
- RPC públicas de acceso controlado mediante `SECURITY DEFINER` y comprobación de rol/subject.
- `anon` no puede ejecutar las nuevas RPC financieras/inventario.
- No se almacenan datos de tarjeta ni IBAN raw.
- Sin JKS, `keystore.properties`, `.p12`, `.mobileprovision` ni claves privadas en el release.
- Secret scan R89: PASS.

Los advisors siguen mostrando findings históricos del proyecto (principalmente funciones SECURITY DEFINER autorizadas, tablas privadas RLS sin políticas directas, índices no usados y protección de contraseñas filtradas). R89 no intenta resolverlos debilitando permisos ni abriendo schemas privados.

## QA

- Gate R89: `48/48 PASS`.
- Regresión acumulativa `npm test`: PASS.
- `release:legal-gate`: PASS.
- `release:build`: PASS.
- i18n estricto ES/EN/FR/PT/IT/DE/TH/FIL: PASS.
- JS syntax de módulos R89: PASS.
- Paridad determinista: `web = dist = Android`, 556 archivos.
- Android preflight: 4/5 preparado; única pieza pendiente = firma local, deliberadamente excluida.
- Gradle compile en este entorno: no ejecutable porque el wrapper no puede resolver `services.gradle.org` para descargar Gradle 8.11.1 (`UnknownHostException`). No es un error de Java/Kotlin detectado.

## Auditoría de eliminación por familias

| Familia | Tratamiento R89 |
| --- | --- |
| Publicaciones/comunicaciones | Archivo/papelera/restauración; media limpiable según preview |
| Eventos privados | Archivo/papelera; delete final protegido por participantes/combates/comunicaciones/conexiones |
| KOMBAX Events público | Cancelación/posposición/cambio mayor preservados; no se habilita borrado destructivo si existe operación/ticketing |
| Materiales Club | Archivo/papelera; histórico de pedidos/entregas protegido |
| Showcase | Archive/delete seguro existente; pedidos y reputación histórica preservados |
| Documentos | Archivo/papelera con Storage controlado |
| Seguimiento/asistencia/sesiones | Ciclo de vida existente; dependencias preservadas |
| Notificaciones | Acciones pendientes bloquean eliminación |
| Cuotas/pagos/recibos/tickets/reembolsos | No borrado libre; históricos financieros preservados |
| Miembros/licencias/verificaciones | No borrado masivo desde R89; se mantienen reglas de estado/baja/revocación existentes |

## Android Studio / Google Play

Abrir `android/` en Android Studio. El proyecto usa build 20142 y conserva el fix de Stripe Terminal basado en `ApplicationInfo.FLAG_DEBUGGABLE`, sin el import erróneo de `BuildConfig.DEBUG`.

Para generar APK/AAB firmado, la firma debe configurarse localmente usando `android/keystore.properties.example` como plantilla y el JKS externo del propietario. Nunca incluir esas credenciales en Git/ZIP.

## Continuidad

A partir de este cierre, la base de continuidad es **R89 build 20142**. No volver a R88/R81 para nuevas implementaciones.

## Certificación adicional de entrega piloto

Tras la primera empaquetación se auditó el ZIP desde una extracción limpia y se corrigió la última milla Android:

- `scripts/android-play-bundle.mjs` genera `KOMBAX_20142_R89_PILOT_GOOGLE_PLAY.aab` y ejecuta previamente `npm run release:build`.
- `scripts/android-debug-qa.mjs` genera `KOMBAX_20142_R89_PILOT_QA_DEBUG.apk`.
- El README raíz identifica R89/20142 como única base vigente para GitHub, Netlify y Android Studio.
- Gate R89 ampliado: 52/52 PASS.
- `npm test` sobre extracción limpia: PASS.
- `npm run release:build` sobre extracción limpia: PASS.
- Secret scan de entrega: 0 secretos / 0 archivos de firma.
- Android API: compileSdk 36 / targetSdk 36 / versionCode 20142.
- La firma local sigue excluida por diseño; el AAB publicable se genera localmente después de preflight 5/5.

Usar el ZIP con sufijo `CERTIFIED_FINAL` como única base de continuidad de esta release.
