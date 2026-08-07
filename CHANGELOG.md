## 1.6.0 build 12
- Recibos de cuota automáticos al completar el pago.
- Numeración anual UW-AAAA-###### y registro inmutable para tesorería.
- Vista breve Urban Warriors en negro y descarga PDF desde la app.
- Notificación de recibo disponible y carga por RLS para socio/tutor/administración.

# 1.6.0 — Gobernanza única de escritura

- Contrato backend versionado y puerta única `app_mutate_v160`.
- DML directo/RPC históricas cerradas al cliente.
- Idempotencia por petición y verificación de membresía.
- Corrección de cabeceras Supabase para claves `sb_publishable_*`.
- Service worker 1.6.0-build11 sin interceptar APIs externas.
- Preflight obligatorio en cada build/Netlify y paridad SHA-256 web/Android.

# Changelog

## 1.4.0
- Cierre operativo del flujo de preinscripción: el socio se crea al aprobar, no antes.
- Lista de espera operativa y notificada.
- Validación de aforo, disciplina, grupo y tarifa al aprobar.
- Confirmación/cierre/recarga homogéneos tras mutaciones.
- Diagnóstico final SQL y pruebas de contratos frontend↔RPC.

## 1.3.0 · 2026-08-06

- CRUD operativo conectado a Supabase para todos los formularios principales.
- Grupos y horarios guardados de forma transaccional.
- Usuarios, invitaciones, preinscripciones y aprobación/rechazo.
- Perfil de progreso, graduaciones y documentos privados.
- Posts, carteles, eventos e imágenes en Supabase Storage.
- Material, variantes, solicitudes y estados con notificaciones.
- Notificaciones de publicaciones generadas en servidor.
- Edge Function genérica `notification-dispatch` preparada para Firebase.
- Caché PWA `1.3.0-build6` y Android `versionCode 6`.

## 1.2.2 · 2026-08-06

- Corrección de errores `Cannot read properties of null` en producción.
- Eliminación de los datos demo cuando Supabase está activo.
- Renovación automática de sesiones JWT.
- Recarga segura de datos tras altas y modificaciones.
- Creación y edición real de alumnos, grupos, material, comunicaciones y notificaciones.
- Imágenes de posts y material mediante el bucket `club-public-media`.
- Migración 006 con campos, Storage y políticas de producción.
- Nueva caché PWA `1.2.2-build5`.

## 1.2.0 · 2026-08-05

- Secuencia automática de cinco avisos de mensualidad: días 1, 4, 8, 11 y 14.
- Configuración de días, hora, canales, agrupación familiar y día de vencimiento.
- Historial idempotente por cuota y destinatario.
- Pausa y reactivación por dirección, secretaría o tesorería.
- Comunicación de pago y justificante privado por el usuario.
- Validación, rechazo, pagos parciales y cancelación de avisos.
- Edge Function, Supabase Cron y preparación Firebase FCM.
- Notificaciones locales Android y versión 1.2.0.
- Manual y cartel integrados en el proyecto.

## 1.1.0 · 2026-08-05

- Acceso general, registro adulto/tutor, pagos, publicaciones, material y notificaciones internas.

## 1.0.0 · 2026-08-05

- Primera fase personalizada para Urban Warriors.

## 1.3.1 — Auditoría operativa

- Alta directa de alumnos validada mediante RPC.
- Grupos con horarios semanales, validación de solapamientos y edición desde la app.
- Confirmación de guardado, cierre de formularios y retorno automático a listas.
- Función SQL `app_auditoria_operativa` para revisar instalación y buckets.
- Prueba estática de doce circuitos funcionales.
