# Urban Warriors RC13 build 20019 · Informe de pulido final previo a deploy/APK

## 1. Identificación

- Base de intervención: `Urban_Warriors_RC13_MVP_build_20018_complete.zip`.
- Resultado: `2.0.0-rc.13` · build / Android `versionCode` **20019**.
- Backend: se conserva `1.6.0`, schema epoch `160` y gateway `app_mutate_v160`.
- Migraciones SQL nuevas en build 20019: **ninguna**.
- 034–036 se conservan byte a byte respecto de build 20018 y ya fueron aplicadas/verificadas en Supabase real durante la validación de esta RC.

## 2. Objetivo

Cerrar tres mejoras de presentación/organización antes de desplegar el candidato al club y antes de generar APK/AAB:

1. distinguir claramente la comunidad interna del club de la futura capa social general;
2. organizar las sesiones recurrentes por semana, mostrando primero lo más próximo;
3. corregir la representación del logo en móvil/launcher para evitar el efecto de un cuadrado dentro de un marco circular.

No se reabre Finanzas, Social 032, Eventos 033 ni la arquitectura SQL ya certificada.

## 3. Comunidad del Club vs Social Community

### Comunidad del Club

El feed existente pasa a presentarse explícitamente como **Comunidad del Club** en:

- navegación;
- cabecera del feed;
- publicación;
- denuncia/bloqueo;
- centro de notificaciones;
- textos de ayuda/privacidad;
- normas del feed interno.

No cambia la clave técnica `comunidad` ni las operaciones del gateway, por lo que no existe migración de datos ni incompatibilidad con el backend.

### Social Community

La futura red general se presenta como **Social Community**, acompañada del descriptor **Comunidad General · servicio social opcional**.

Se mantiene exactamente la infraestructura 036 ya desplegada: no se activa un feed global en esta build.

## 4. Sesiones organizadas por semana

### Gestión/equipo

`renderSessions()` conserva la generación de recurrencias y el histórico, pero la vista de ocurrencias se limita a una semana natural (lunes–domingo).

Se añade navegación:

- `Semana anterior`;
- `Esta semana`;
- `Semana siguiente`.

En la semana actual el orden es:

1. próxima sesión futura;
2. siguientes sesiones futuras en orden cronológico;
3. sesiones ya pasadas de esa semana, de la más reciente hacia atrás.

Así una serie con dos ocurrencias semanales muestra dos; una serie con tres, tres. No se cargan visualmente las 12 semanas generadas como una lista continua.

### Portal alumno/familia

La misma organización semanal se aplica a `Horarios y asistencia`.

Las sesiones ya pasadas pueden consultarse como contexto, pero no ofrecen confirmar/cancelar asistencia; se muestran como `Sesión pasada`.

### Persistencia

No se modifica:

- `series_sesiones`;
- `sesiones_entrenamiento`;
- generación recurrente;
- reservas;
- check-in;
- asistencia;
- excepciones;
- histórico.

El cambio es exclusivamente de cálculo de rango, orden y presentación.

## 5. Logo / launcher

### Dentro de la aplicación

Los logos del club se muestran en marco circular y con recorte `cover` en los contextos de marca relevantes:

- sidebar;
- login móvil/escritorio;
- vista previa de branding;
- perfil público del club;
- resultado de directorio cuando la identidad es un club.

El componente no depende del nombre Urban Warriors y puede reutilizarse con futuros clubes.

### PWA

Se normalizan los iconos existentes y se añaden:

- `icon-maskable-192.png`;
- `icon-maskable-512.png`.

`manifest.webmanifest` declara iconos normales y `maskable`, para que Android pueda aplicar su propia forma sin introducir un segundo recuadro visual.

### Android nativo

Se regeneran los launchers legacy y se añade soporte adaptive icon para API 26+:

- `mipmap-anydpi-v26/ic_launcher.xml`;
- `mipmap-anydpi-v26/ic_launcher_round.xml`;
- `drawable/ic_launcher_foreground.png`;
- `launcher_background = #050608`.

La corrección exacta debe confirmarse en un dispositivo físico después de compilar build 20019; la preparación estática sí queda implementada.

## 6. Versionado

Se incrementa únicamente el build:

- config web: `20019`;
- cache/service worker: `rc13-20019`;
- query strings del frontend: `v=20019`;
- Android `versionCode 20019`;
- `versionName` se conserva en `2.0.0-rc.13`;
- `applicationId` se conserva en `com.urbanwarriors.app`.

Esto evita confundir build 20018 con el candidato que realmente se desplegará/probará.

## 7. Pruebas añadidas

Nuevo test `scripts/test-rc13-final-polish.mjs` que verifica:

- semana lunes–domingo;
- navegación a semana siguiente;
- orden próxima sesión → siguientes → histórico;
- filtrado semanal en gestión;
- filtrado semanal en portal;
- bloqueo de confirmación/cancelación en sesión pasada;
- nomenclatura `Comunidad del Club`;
- nomenclatura `Social Community`;
- CSS circular de logos;
- iconos PWA maskable;
- adaptive icon Android;
- versionado coherente 20019.

Los tests históricos se mantienen y solo se actualizan sus expectativas de número de build/nomenclatura deliberadamente modificada.

## 8. Certificación local final

Ejecución final:

- `node --check`: **57/57** JS/MJS, 0 fallos.
- `npm test`: **583** comprobaciones `OK`, **29** marcadores `PASS`, 0 `FAIL`.
- contrato backend: **93/93** operaciones.
- `npm run build`: **PASS**.
- paridad: **51 archivos**, `web = dist = android/app/src/main/assets/www`.
- comparación `supabase/` build 20018 vs 20019: **sin diferencias**.
- `scripts/serve.mjs`: `127.0.0.1` (el cambio LAN temporal no queda certificado en el paquete).
- capability gate: no se introduce bypass.

## 9. Qué NO se declara completado

Todavía no se declara:

- deploy Netlify de build 20019;
- APK release build 20019 compilada/firmada;
- AAB build 20019;
- verificación física del nuevo adaptive icon;
- instalación 20019 encima de la APK anterior;
- pruebas finales push/foreground/background/cámara;
- freeze/tag final;
- publicación o aprobación de Google Play.

Estas puertas se realizan después de que el usuario copie el paquete al PC y haga una pasada local rápida del 20019.

## 10. Próximo orden operativo

1. Descomprimir build 20019 en una carpeta nueva del PC.
2. Ejecutar `npm run dev` y probar en Chrome contra Supabase ya actualizado.
3. Validar `Comunidad del Club`, `Social Community`, Sesiones por semana y logo.
4. Para prueba LAN móvil, cambiar temporalmente el bind a `0.0.0.0`, probar y volver a `127.0.0.1` antes del freeze.
5. Si la pasada es limpia, desplegar el mismo build web en Netlify para validación del club.
6. Abrir el mismo proyecto en Android Studio, compilar APK/AAB 20019 y probar actualización encima de la APK anterior.
7. Solo entonces valorar freeze y Google Play.
