# KOMBAX RC13 · Build 20041
## Validación de ciclo de vida del contenido y multimedia adaptativa

Fecha de validación: 2026-08-18
Base: RC13 build 20040
Build resultante: 20041

## 1. Alcance

La 20041 consolida dos objetivos de QA:

1. Dar una salida de eliminación coherente al contenido creado por usuarios en las superficies auditadas.
2. Evitar que imágenes o vídeos verticales/horizontales se deformen, se recorten de forma involuntaria o crezcan sin límite en tarjetas, perfiles y vistas de detalle.

La regla visual aplicada es:

- Contenido (foto/vídeo): conservar proporción completa con `object-fit: contain` y límites de tamaño.
- Identidad (avatar/logo): recorte controlado con `object-fit: cover` cuando el marco de identidad lo exige.
- Miniatura de foto de álbum: puede usar `cover` para mantener una cuadrícula regular; la visualización completa conserva la imagen con `contain`.

## 2. Matriz de eliminación

| Superficie | Estado 20041 |
|---|---|
| KOMBAX Social · publicación propia | NUEVO: eliminar publicación; interacciones dependientes se eliminan por FK; multimedia Social huérfana y no guardada en álbum pasa a `removed` y el cliente elimina el archivo propio de Storage. |
| Contacto KOMBAX | NUEVO: “Eliminar conversación” por participante. Cierra el hilo y lo oculta solo para quien lo elimina; no destruye la copia de la contraparte. |
| Showcase | NUEVO: eliminación física de la ficha por gestor autorizado; guardados dependientes se eliminan por FK; el cliente limpia imágenes propias de Storage. |
| Perfil público · foto/avatar | NUEVO: eliminación explícita de la foto pública actual. |
| Perfil público · portada | NUEVO: eliminación explícita de la portada pública actual. |
| Álbum de club/perfil | Existente: eliminación de media; wording de UI unificado a “Eliminar”. |
| Comunidad interna | Existente: eliminación de publicaciones + limpieza de media cuando corresponde. |
| Comunicaciones/avisos del club | Existente: ciclo de eliminación/archivo según tipo + limpieza de imagen. |
| Material/tienda del club | Existente: eliminación de material + limpieza de imágenes; sustitución y retirada de imagen controladas. |

Nota de privacidad: Contacto KOMBAX no usa hard-delete unilateral de mensajes privados. Cada participante puede retirar el hilo de su propia bandeja; la contraparte conserva su copia hasta que también la elimine.

## 3. Matriz multimedia

| Superficie | Foto vertical/horizontal | Vídeo vertical/horizontal | Regla |
|---|---|---|---|
| KOMBAX Social feed | Sí | Sí | `contain`, altura máxima, sin crop automático. |
| Comunidad del club | Sí | Sí | `contain`. |
| Perfil Social · portada | Sí | N/A | `contain`; se preserva la composición completa. |
| Avatar/logo | Sí | N/A | `cover` intencional por ser identidad. |
| Álbum · foto miniatura | Sí | N/A | `cover` solo en grid; visor completo `contain`. |
| Álbum · vídeo | N/A | Sí | `contain`. |
| Showcase · tarjeta | Sí | No soportado actualmente | Marco acotado + `contain`. |
| Showcase · detalle/galería/guardados | Sí | No soportado actualmente | `contain`, altura máxima. |
| Showcase dentro del perfil público | Sí | No soportado actualmente | Marco acotado; 104 px desktop / 88 px móvil + `contain`. |
| Perfil público del club · portada | Sí | N/A | fondo en `contain`, centrado, sin crop involuntario. |
| Material/tienda · tarjeta/detalle | Sí | N/A | `contain`, detalle con altura máxima. |

## 4. Backend 067 aplicado

Migración aplicada al proyecto Supabase real:

- `067_kombax_content_lifecycle_media_20041.sql`
- Proyecto: `poggsobhtutbuagjiydc`

Añadido:

- `kombax_social_contactos.eliminado_remitente_en`
- `kombax_social_contactos.eliminado_destinatario_en`
- `app_kombax_contact_can_access_v067`
- `app_kombax_contactos_v067`
- `app_kombax_contact_mensajes_v067`
- `app_kombax_contact_mark_read_v067`
- `app_kombax_social_network_mutate_v067`
- `app_kombax_social_mutate_v067`
- `app_kombax_showcase_mutate_v067`

Privilegios verificados:

- helper interno v067: no ejecutable por `anon` ni `authenticated`.
- gateways v067 de cliente: ejecutables por `authenticated`, no por `anon`.

## 5. QA real de Supabase

### Contacto KOMBAX

Se verificó con un hilo QA temporal que la eliminación por participante:

- marca solo el tombstone del actor;
- mantiene el tombstone de la contraparte vacío;
- cierra el hilo;
- impide que el actor lo vuelva a ver mediante los gateways v067.

Después de la prueba se eliminaron explícitamente el hilo QA, su auditoría y su registro de idempotencia.

El hilo real Urban Warriors ↔ Bryan Rivera quedó intacto:

- estado: `aceptada`;
- mensajes: `1/20`;
- `eliminado_remitente_en`: NULL;
- `eliminado_destinatario_en`: NULL.

### KOMBAX Social

Se creó una publicación QA aislada con media QA y se ejecutó `kombax.social.eliminar`:

- `deleted=true`;
- publicación restante: 0;
- media huérfana: `removed`;
- `media_removed=true`.

Después se limpiaron la media QA, auditoría e idempotencia.

### Showcase

Se creó una ficha QA aislada y se ejecutó `kombax.showcase.elemento.eliminar`:

- `deleted=true`;
- ficha restante: 0;
- se verificó auditoría de la acción.

Después se limpiaron auditoría e idempotencia QA.

### Residuo QA final

Consulta final:

- contactos QA: 0
- publicaciones QA: 0
- media QA: 0
- Showcase QA: 0
- auditoría QA: 0
- peticiones idempotentes QA: 0

## 6. Tests estáticos y regresión

Nueva prueba:

- `scripts/test-kombax-20041-content-lifecycle-media.mjs`

Cubre:

- build 20041;
- eliminación Social;
- eliminación por participante de Contacto;
- eliminación Showcase;
- eliminaciones ya existentes de material/comunicaciones;
- `contain` en contenido;
- marco acotado de Showcase público;
- `cover` intencional solo para identidad;
- eliminación de avatar/portada pública.

Resultado de `npm run build`:

- suite histórica RC4 → 20041: PASS
- `KOMBAX BUILD 20041 CONTENT LIFECYCLE + ADAPTIVE MEDIA: PASS`
- `OK build 62 archivos · web = dist = Android`

Resultado de `npm run certify:static`:

- PASS

## 7. Sincronización web / dist / Android

Comparación SHA-256 independiente de los 62 archivos del frontend:

- web: 62
- dist: 62
- Android assets: 62
- web = dist: 0 faltantes, 0 extras, 0 hashes distintos
- web = Android: 0 faltantes, 0 extras, 0 hashes distintos

## 8. Smoke HTTP

Servidor local aislado:

- `http://127.0.0.1:4176`

Comprobado:

- assets `v=20041`: OK
- config build 20041: OK
- CSS de contenido adaptativo: OK
- Showcase público acotado: OK
- control de eliminación Showcase: OK

## 9. Android

Preflight:

- applicationId: OK
- versionCode 20041: OK
- web embebida: OK
- Firebase: OK
- firma release JKS: PENDIENTE LOCAL

Resultado: 4/5.

No se certifica APK/AAB release firmada en este entorno.

## 10. Seguridad y secretos

Escaneo del paquete:

- JKS: 0
- `.keystore`: 0
- `keystore.properties`: 0
- P12/PFX/PEM: 0
- service-account JSON: 0
- literales de secretos detectados fuera de configuración pública Firebase: 0

El asesor de seguridad de Supabase sigue mostrando avisos históricos del proyecto sobre RPC `SECURITY DEFINER`, tablas internas cerradas por RLS sin políticas directas y protección de contraseñas filtradas. La 20041 no introduce un nuevo gateway v067 ejecutable por `anon`.

## 11. Rollback 067

Existe:

- `supabase/rollbacks/067_kombax_content_lifecycle_media_20041_rollback.sql`

El rollback está bloqueado de forma deliberada. Volver directamente a gateways 065 ignoraría los tombstones de conversaciones y podría hacer reaparecer hilos que un usuario ya hubiera eliminado. Una reversión segura debe conservar primero esas marcas de privacidad.

## 12. Limitación de validación visual automatizada

Se intentó una captura headless de prueba con Chromium para vertical/horizontal. El proceso quedó bloqueado por servicios del sistema del contenedor y fue terminado por timeout sin producir captura. Esta prueba NO se cuenta como superada.

La validación cubierta y certificada en este build es: CSS/regresión estática, sincronización, smoke HTTP y backend real. La inspección visual humana en dispositivo/navegador forma parte del QA manual de 20041.
