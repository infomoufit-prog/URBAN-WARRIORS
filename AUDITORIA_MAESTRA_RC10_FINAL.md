# Auditoría maestra · Urban Warriors 2.0.0-rc.10 · FINAL MVP

## Objetivo

RC10 cierra el alcance funcional del MVP sobre la base RC9 ya certificada. Mantiene el contrato estable `backend 1.6.0`, `schema epoch 160` y la puerta única `app_mutate_v160`. No reabre la arquitectura de persistencia.

## Alcance auditado e implementado

### 1. Notificaciones escalables
- Bandeja agrupada por finalidad, no una fila operativa por cada evento.
- Bloques de **Requiere acción**, sesiones, comunidad, comunicaciones y otros.
- Marcar una, un grupo o todas como leídas.
- Contador de campana basado en grupos pendientes relevantes.
- Preferencias push por categorías: general, finanzas, sesiones y comunidad.

### 2. Sesiones recurrentes
- Series semanales por uno o varios días.
- Horizonte móvil de ocurrencias futuras.
- Excepciones de una sola fecha: cancelación, monitor sustituto, cambio de sala/hora y motivo.
- Edición/finalización de serie preservando ocurrencias con histórico.
- Reserva previa y check-in continúan siendo conceptos independientes.

### 3. Comunidad temporal
- Feed separado de publicaciones oficiales.
- Alumno/familia: máximo 3 publicaciones por mes.
- Equipo del club: máximo 5 publicaciones sociales por mes.
- Una imagen o un vídeo de hasta 15 segundos.
- Retención máxima configurada a 30 días.
- Limpieza de la fila y del archivo físico mediante `notification-dispatch` cuando se ejecuta el mantenimiento programado.
- Autor puede eliminar lo suyo; equipo autorizado puede moderar.
- Sin perfiles públicos navegables, comentarios, seguidores ni mensajería privada.

### 4. Perfil personal
- Foto de perfil privada + nombre.
- Avatar visible en la experiencia propia y en Comunidad.
- Sustitución/eliminación limpia el archivo anterior.

### 5. Finanzas / Tesorería
- Conserva tarifa → cuota → pago → validación → recibo.
- Nuevo estado de cuenta por socio/familia.
- Métricas de cobrado validado, pendiente, vencido y pagos por validar.
- Worker de cobros limitado a notificaciones financieras y preferencias de usuario.

### 6. Push
- `notification-dispatch` y `payment-reminders` preparados para Firebase Cloud Messaging.
- Preferencias de categorías respetadas.
- Android registra/resincroniza token y conserva ruta al abrir una push.
- **No se declara push de producción certificado** hasta configurar credenciales Firebase reales, desplegar/planificar Edge Functions y superar una prueba en dispositivo físico con la app cerrada.

### 7. Perfil legal y consentimientos
- Condiciones de uso, privacidad, Comunidad y autorización de imagen versionadas `2.0.0`.
- Condiciones y privacidad accesibles en registro.
- Autorización de imagen separada y opcional.
- Registro de aceptación/retirada con versión y marca temporal.
- Consulta posterior desde Privacidad y condiciones.

### 8. Formación y recursos
- Manual de usuario actualizado.
- Manual de equipo/Coordinación actualizado.
- Ayuda integrada en la app.
- Cartel/hoja de descarga restringido a Gestor de la app, Coordinación y Secretaría.

## Seguridad y gobernanza

- No se habilita DML directo desde módulos UI.
- Las nuevas mutaciones atraviesan `app_mutate_v160`.
- Los buckets de perfil y Comunidad son privados.
- Los documentos continúan en Storage privado.
- `direccion` permanece como clave interna del **Gestor de la app** para compatibilidad.
- Coordinación sigue sin adquirir `direccion` ni herramientas técnicas de máximo nivel.

## Migración

Nueva migración única: `022_rc10_final_mvp_v166.sql`.

Copia para SQL Editor: `SQL_EJECUTAR_RC10_022.sql`.

El script termina con un diagnóstico seguro para SQL Editor:

```sql
select * from public.app_diagnostico_instalacion_v166();
```

Debe devolver **12 controles en OK**.

## Resultado local

- `npm test`: PASS.
- Contrato frontend/backend: 74/74 operaciones del gateway detectadas.
- Regresiones RC4–RC9: PASS.
- Suite específica RC10: PASS.
- `npm run build`: PASS.
- Paridad Web = dist = Android: 38 archivos.
- Android: `2.0.0-rc.10`, `versionCode 20010`.

## Condiciones para congelar el MVP

1. Ejecutar SQL 022 en la base real y obtener 12/12 OK.
2. Ejecutar E2E desde Chrome con cuenta Gestor.
3. Realizar pruebas manuales de Comunidad, recurrencia, cuenta financiera, avatar, legal y acciones masivas de notificación.
4. Hacer un único deploy GitHub/Netlify.
5. Configurar y probar push real en Android físico.
6. Tras ello, promover a `2.0.0` estable y preparar APK/AAB firmado.
