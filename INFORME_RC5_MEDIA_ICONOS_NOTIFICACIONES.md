# Urban Warriors 2.0.0-rc.5 · Media, iconografía y notificaciones

## Alcance

RC5 parte de RC4 Premium y corrige tres remates de producto sin cambiar el contrato SQL ni las migraciones:

1. retirar información técnica de la experiencia cotidiana;
2. unificar la iconografía con SVG propios y coherentes;
3. completar multimedia de publicaciones/material y el centro de notificaciones.

## 1. Información técnica fuera del uso cotidiano

- Login: sin versión, build, Supabase, backend ni epoch.
- Topbar: muestra club y rol, no versión/backend.
- Sidebar: marca + `Bring the Pain`, sin etiqueta técnica.
- Dirección: Diagnóstico y Certificación E2E dejan de aparecer en la navegación normal.
- Las herramientas técnicas siguen disponibles exclusivamente para Dirección desde **Configuración → Herramientas técnicas**.

No se elimina la capacidad de diagnóstico; se separa del producto cotidiano.

## 2. Iconografía profesional

Se añade `web/js/ui/icons.js`, un sistema SVG inline, sin emojis ni librerías externas.

Se utiliza en:
- navegación lateral y navegación inferior móvil;
- menú, notificaciones, logout y cierres;
- quick actions y portal Familia/Alumno;
- dashboards y acciones financieras;
- equipo, instalación y certificación;
- publicaciones, material y bandeja de notificaciones.

Los SVG usan `currentColor`, por lo que respetan el design system, estados y accesibilidad visual.

## 3. Multimedia persistente en Supabase

RC5 usa el bucket existente `club-public-media`, ya creado y protegido por las migraciones históricas.

### Publicaciones

El formulario permite seleccionar directamente JPG, PNG, WEBP o GIF (máximo 5 MB). El flujo es:

`archivo → Storage club-public-media → URL pública → publicacion.guardar → comunicaciones.imagen_url → feed`

La ruta del objeto se particiona por `club_id` y tipo (`communications`).

### Material

Mismo flujo mediante la carpeta `material`. Una edición sin nuevo archivo conserva la imagen existente.

### Sin cambio SQL

No se añade ninguna migración. Las migraciones 001→017 mantienen exactamente el mismo SHA-256 agregado que la base RC3/RC4 certificada.

## 4. Publicaciones y notificaciones

La lógica de autoridad ya existía en SQL y RC5 la conecta correctamente con la experiencia de usuario:

- una publicación con estado `publicada` crea la notificación dentro de la misma operación SQL;
- audiencia `todos`: visible para miembros del club;
- audiencia `familias`: genera destino `familia` + `alumno`;
- audiencia `monitores`: genera destino `monitor`;
- `notificada_en` evita duplicados;
- las lecturas individuales de notificaciones compartidas se resuelven con `notificaciones_lecturas`.

### Experiencia RC5

- campana global con contador de no leídas;
- al entrar se avisa si existen notificaciones pendientes;
- durante la sesión se consulta el centro cada 45 s;
- una publicación creada desde la app fuerza refresco inmediato del contador;
- las nuevas notificaciones muestran toast;
- si el navegador ya tiene permiso y está en segundo plano, se utiliza la API Notification del navegador;
- la bandeja permite abrir la ruta asociada y marcar la notificación como leída.

### Push servidor

Se conserva la Edge Function `notification-dispatch`, que publica comunicaciones programadas y envía FCM a dispositivos registrados cuando `FIREBASE_SERVICE_ACCOUNT_JSON` y la ejecución programada/cron están configuradas en el entorno real. RC5 no puede certificar desde código que esos secretos/cron estén activos en el proyecto desplegado; debe verificarse operacionalmente si se requiere push con la app cerrada.

## 5. Seguridad

- No se añade DML directo.
- Las publicaciones siguen pasando por `app_mutate_v160`.
- Las imágenes pasan por Storage con JWT real del usuario.
- El bucket limita tamaño/MIME en servidor.
- Las policies de Storage mantienen el control por `club_id` y rol.
- RLS sigue controlando qué publicaciones/notificaciones puede leer cada usuario.

## 6. Cambios de cliente de bajo riesgo

`supabase.js` y `backend.js` reciben únicamente el helper `publicUrl()` para construir la URL del bucket público. La lógica de Auth, contrato y `mutate()` no se modifica.

## 7. Versión

- Frontend: `2.0.0-rc.5`
- Android versionCode: `20005`
- Backend esperado: `1.6.0`
- Schema epoch: `160`

## 8. Certificación antes de Netlify

Mantener el método ya validado:

1. `npm install`
2. `npm run build`
3. `npm run dev`
4. entrar como Dirección en localhost;
5. ejecutar **Configuración → Herramientas técnicas → Certificación E2E**;
6. comprobar además una publicación de prueba con imagen desde localhost y confirmar que aparece en el feed y la campana registra el aviso.

No hacer deploy a Netlify hasta completar estas comprobaciones locales.
