# KOMBAX RC13 build 20063 · PLAN DE IMPLEMENTACIÓN FINAL SOCIAL + MENSAJERÍA

Fecha: 2026-08-20
Base canónica de entrada: **KOMBAX RC13 build 20062 · COMPETITOR REOPEN + FOUNDERS PROMO**.
Objetivo operativo: crear una candidata **20063** para validación móvil mediante APK sin desplegarla todavía en Netlify.

## Invariantes

- La build 20062 permanece como versión web desplegada de referencia durante la QA móvil.
- No hacer deploy Netlify de 20063 hasta aprobación/freeze manual.
- Mantener `applicationId com.urbanwarriors.app` y el mismo JKS/alias local existentes.
- No empaquetar JKS, contraseñas, `keystore.properties` real ni secretos.
- No hacer refactor transversal innecesario: intervención final centrada en KOMBAX Social, Mensajes y enlace comercial Showcase.
- Mantener ownership, RLS, aislamiento multiclub, Contact Gate 18+, bloqueos, moderación y auditoría.

## Fase 1 · Chat Social — IMPLEMENTADA

1. Eliminar de la UI la acción **Cerrar chat**.
2. La `X` cierra únicamente la ventana y conserva el hilo.
3. La `X` detiene el poller/sincronización de la ventana que deja de estar visible.
4. Mantener **Eliminar conversación** como acción destructiva con confirmación.
5. Mantener lectura, envío, histórico, autosync y recibos de lectura existentes.

## Fase 2 · Comentarios inline — IMPLEMENTADA

1. Eliminar el segundo modal/pantalla `Añadir comentario`.
2. `Comentarios` despliega comentarios y compositor dentro del contexto de la publicación.
3. Campo de escritura + envío directo.
4. Conservar respuestas, borrado propio, denuncia, identidad autora, permisos y cierre de comentarios.

## Fase 3 · Mi red — IMPLEMENTADA

Terminología de producto normalizada:

- `Relaciones` → **Mi red**.
- `Solicitar relación` / `Vincular` → **Añadir a mi red**.
- aceptación → **Aceptar en mi red**.
- eliminación → **Eliminar de mi red**.

La implementación interna puede conservar nombres históricos de tablas/RPC para reducir riesgo. La red sigue privada: sin listado público, sin contador público y sin métrica de popularidad.

## Fase 4 · Mensajes y badge — IMPLEMENTADA EN CLIENTE / CONTRATO v107 PREPARADO

1. Acceso superior independiente **Mensajes KOMBAX**.
2. Badge numérico separado de Notificaciones KOMBAX y Notificaciones del Club.
3. Click del icono → bandeja de Mensajes.
4. Contrato v107 cuenta **conversaciones con mensajes no leídos**, no cada mensaje individual.
5. Notificaciones generales no duplican el contenido de los chats.

## Fase 5 · Social vs Showcase — IMPLEMENTADA EN FRONTEND / BACKEND 107 PREPARADO

Bandeja única con filtros:

- Todos
- Social
- Showcase

Diferenciación visual:

- Social: tratamiento KOMBAX Social.
- Showcase: tratamiento comercial específico, etiqueta e información del producto.

Cada hilo Showcase se vincula a un producto concreto y conserva snapshot de:

- ID del producto;
- nombre;
- imagen;
- marca/proveedor.

Las mismas dos identidades pueden mantener hilos Showcase distintos para productos diferentes.

## Fase 6 · CTA Showcase — IMPLEMENTADA

- `Me interesa`/contacto comercial puede iniciar conversación Showcase.
- Si el CTA principal es externo, se añade **Consultar en Showcase** cuando existe proveedor Social válido.
- El hilo se abre desde Mensajes y muestra el producto en cabecera.
- Contact Gate inicial: 10–500 caracteres.

## Fase 7 · Backend Supabase — PREPARADO, NO APLICADO A LIVE EN ESTE CIERRE

Archivo:
`supabase/migrations/107_kombax_social_showcase_messaging_20063.sql`

Incluye:

- canal `social|showcase`;
- contexto/snapshot de producto;
- índice de hilo Social abierto por pareja;
- índice de hilo Showcase abierto por pareja+producto;
- RPC v107 de creación de contacto;
- listado v107;
- badge v107 por conversaciones no leídas;
- compatibilidad v106/v104 para build 20062;
- preflight, verificación y rollback conservador.

El estado live fue auditado en modo lectura: tablas/RPC previos requeridos existen, el esquema aún no contenía `canal` y las parejas abiertas existentes eran consistentes. **No se aplicó DDL live** para no modificar silenciosamente el backend compartido durante el empaquetado de la candidata móvil.

El cliente 20063 implementa fallback seguro:

- Social: v107 → v104/v106 si v107 aún no existe.
- Showcase comercial: no simula ni degrada el modelo; muestra un error humano indicando que debe activarse backend 107.

## Fase 8 · QA automática — COMPLETADA

- Nueva regresión `scripts/test-kombax-20063-social-messaging-final.mjs`: PASS.
- `npm test`: PASS.
- `npm run build`: PASS.
- Builder: **66 archivos · web = dist = Android**.
- Diferencias SHA-256 entre web/dist/Android: 0.
- Android `versionCode`: **20063**.
- Secret audit local: 0 JKS/keystore/P12/PFX/PEM/KEY y 0 `keystore.properties` real.

## Fase 9 · APK móvil — PROYECTO LISTO / BINARIO SIGNED PENDIENTE DE ENTORNO LOCAL

Android preflight:

- applicationId: OK.
- versionCode 20063: OK.
- assets/www: OK.
- Firebase: OK.
- firma local: PENDIENTE porque el paquete no incluye `android/keystore.properties` ni JKS.

En este entorno no se pudo compilar el APK binario porque Gradle 8.11.1 no está cacheado y el runtime no tiene acceso de red para descargar la distribución. No se debe inventar un APK ni sustituir el JKS.

La generación signed se hará con el **mismo JKS y alias ya usados para la 20062** en Android Studio del equipo local.

## Orden de validación manual recomendado

1. Instalar APK signed 20063 en Android real.
2. Validar Mi red y terminología.
3. Validar Comentarios inline.
4. Validar chat Social: abrir → escribir → X → reabrir → historial preservado.
5. Validar Eliminar conversación y confirmación.
6. Validar badge Mensajes y descenso al leer conversaciones.
7. Activar migración 107 de forma controlada.
8. Validar Showcase: producto A → consulta → imagen/nombre en hilo.
9. Misma pareja → producto B → hilo distinto.
10. Validar filtros Todos/Social/Showcase.
11. Validar 20062 web después de backend 107 antes de cualquier deploy 20063.
12. Si todo pasa: freeze 20063 → deploy Netlify → generar/verificar AAB signed → Google Play.

## Criterio de freeze

20063 no se declara freeze hasta completar Android real + dual account + Showcase E2E + regresión de la web 20062 tras activar 107.
