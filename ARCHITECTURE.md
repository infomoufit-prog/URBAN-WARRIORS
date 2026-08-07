# Arquitectura Urban Warriors 1.3.0

## Cliente

La PWA y la aplicación Android comparten el contenido de `web/`. `scripts/build.mjs` copia esa versión a `dist/` y a `android/app/src/main/assets/www`.

## Backend

Supabase proporciona Auth, PostgreSQL, RLS, Storage y Edge Functions. El frontend utiliza operaciones RPC transaccionales para los formularios de negocio, evitando escrituras parciales y diferencias entre web y APK.

## Persistencia

- Catálogo público: disciplinas, grupos, horarios y tarifas activas.
- Datos privados: socios, tutores, pagos, asistencia, seguimiento y documentos.
- Medios públicos: `club-public-media`.
- Justificantes privados: `justificantes-pago`.
- Documentos privados: `member-documents`.

## Alertas

`procesar_avisos_cobro` genera los cinco avisos internos. `payment-reminders` ejecuta el calendario económico. `notification-dispatch` publica contenido programado, resuelve destinatarios y envía las notificaciones pendientes por FCM cuando Firebase está configurado.
