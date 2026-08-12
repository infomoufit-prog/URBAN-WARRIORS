# Urban Warriors 2.0.0 RC12 · Implementación integral previa a publicación

Base: RC10 estable + Bloque 1 RC11 (Android/push/safe-area).

## Implementado

### Android / push / safe areas
- Safe area superior e inferior reforzada.
- Contenido y modales reservan la zona de navegación Android.
- Solicitud guiada del permiso POST_NOTIFICATIONS.
- Apertura de ajustes si el permiso fue bloqueado/denegado.
- Resincronización del token FCM.
- Las preferencias individuales de categorías push dejan de bloquear el despacho: autorizado Android => el dispositivo recibe los avisos que emite el club.

### Comunidad escalable
- Feed paginado en bloques de 20, con carga progresiva.
- Imágenes lazy-loading y vídeos con preload=none.
- Imágenes grandes redimensionadas/comprimidas en cliente.
- Vídeos limitados a 15 s, 50 MB y máximo 1080p.
- Portada de vídeo automática.
- Portada manual opcional al publicar.
- Portada y multimedia se eliminan en limpieza/retención.
- Índice de cursor multi-club para crecimiento del feed.

### Finanzas
- Selector de ejercicio anual.
- Historial económico por ejercicio conservando años anteriores.
- Origen del cargo: cuota / material / otro.
- Métricas internas: generado, cobrado, pendiente, tasa de cobro, movimientos de material y pagos por validar.
- Vista alumno/familia simplificada: total pendiente, movimientos, pagos comunicados.

### Materiales
- Alumno/familia puede declarar material cogido: queda pendiente de validación.
- Coordinación/Secretaría/Dirección/Economía puede registrar entrega directamente.
- Validación crea entrega trazable + cargo pendiente en Finanzas.
- El cargo de material usa el mismo circuito de pagos y avisos que las cuotas.
- Historial muestra origen, validación, estado, importe y artículo.

### Avisos de cobro
- Los recordatorios incluyen cuotas y material.
- Se vuelven a considerar saldos antiguos pendientes, no solo el mes actual.
- Mensajes genéricos de pago pendiente con conceptos y total.
- Push financiero no se filtra por preferencias individuales antiguas.

### Seguridad / multi-club
- Todas las consultas siguen filtradas por club_id.
- Storage de Comunidad sigue segmentado por club/perfil.
- El alumno/familia no puede validar su propio cargo de material.
- La validación financiera queda en roles autorizados.
- Índices adicionales para feed, cuotas y material.

## Migración nueva
`supabase/migrations/023_scalability_finance_materials_v167.sql`

Debe aplicarse antes de publicar el frontend RC12 que usa las nuevas operaciones.

## Edge Functions modificadas
- `supabase/functions/notification-dispatch/index.ts`
- `supabase/functions/payment-reminders/index.ts`

Deben desplegarse al activar RC12 en producción.

## Orden de despliegue recomendado (cuando se decida publicar)
1. Backup lógico / conservar RC10.
2. Ejecutar migración 023 en Supabase y verificar que termina sin error.
3. Desplegar las dos Edge Functions actualizadas.
4. Ejecutar pruebas de push real y material/cargo en un usuario de prueba.
5. Commit/push a GitHub y esperar deploy de Netlify.
6. Verificar web/PWA.
7. Generar APK release RC12 con el mismo keystore de producción.
8. Instalar encima de la APK anterior y probar push con app cerrada/segundo plano.

## Validación local realizada
- `npm test`: PASS.
- `npm run build`: PASS.
- Build certifica `web = dist = Android` (44 archivos).
- Test específico `test-rc12.mjs`: PASS.

La compilación Gradle no se ejecutó en este entorno porque el ZIP limpio no contiene `gradlew`/wrapper. Se hará en Android Studio/local, donde ya se ha generado release anteriormente.


## Ajuste posterior: vídeo 50 MB
- Ejecutar también `supabase/migrations/024_community_video_50mb_v168.sql` para elevar el límite real del bucket `community-media` a 50 MB.
- La aplicación rechaza vídeos superiores a 50 MB y mantiene los límites de 15 s y 1080p.
