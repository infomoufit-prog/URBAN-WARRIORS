# KOMBAX · BUILD 20058 · NAVIGATION + SESSION UX · VALIDATION

Fecha: 2026-08-20
Base: build 20057 · SUPABASE CONSOLIDATION
Estado: **PASS AUTOMÁTICO / VALIDACIÓN MANUAL PENDIENTE**

## Alcance de esta primera intervención 20.058

La intervención se ha limitado deliberadamente a una capa de bajo riesgo antes de tocar realtime o nuevos contratos de datos:

1. Reestructuración visual de navegación sin ensanchar permisos.
2. Mi perfil / Social / Showcase como destinos globales.
3. Mi Club como acordeón para rutas operativas del tenant.
4. Dirección/Coordinación separan perfil personal y perfil de club.
5. Notificaciones actuales se identifican como Notificaciones del Club y salen del menú lateral.
6. UX móvil: acceso al menú más visible y bottom-nav centrado en los cuatro destinos principales.
7. Resiliencia de sesión ante refresh token inválido y pérdida temporal de red.

No se han implementado todavía fuentes nuevas de Notificaciones KOMBAX ni Mensajes en cabecera. No se muestra ningún contador ficticio. Eso se reserva para la siguiente intervención, tras auditar el contrato de datos necesario.

## Seguridad y compatibilidad

- Las rutas permitidas continúan derivándose de `navFor(session)`; la nueva jerarquía solo cambia presentación/orden.
- Dirección/Coordinación conservan el hub del Club como `Perfil del club` y obtienen `Mi perfil` personal como entrada global.
- Los roles Monitor/Economía conservan sus accesos operativos dentro de Mi Club; se actualizó una regresión histórica que asumía el bottom-nav antiguo.
- `Invalid Refresh Token: Refresh Token Not Found` se clasifica como `AUTH_EXPIRED`, limpia el token inválido y vuelve a login con `Tu sesión ha caducado. Vuelve a iniciar sesión.`
- Los fallos transitorios de red durante `restore()` conservan el contexto local en vez de cerrar sesión.
- No hay migraciones Supabase ni cambios SQL en build 20058 intervención 1.

## Pruebas

- Test nuevo: `scripts/test-kombax-20058-navigation-session-ux.mjs`.
- `npm test`: PASS.
- `npm run build`: PASS.
- Build determinista: `65` archivos en web, `65` en dist, `65` en Android.
- Comparación independiente: listas iguales, `0` diferencias SHA-256 archivo a archivo.
- Android preflight: 4/5; firma local pendiente deliberadamente (`android/keystore.properties`).

## Auditoría de secretos

- 0 almacenes JKS/keystore/P12/PFX incluidos.
- 0 claves privadas incluidas.
- Las referencias `SUPABASE_SERVICE_ROLE_KEY` presentes son lecturas de variables de entorno o assertions de test, no valores de credenciales.
- `android/app/google-services.json` contiene la clave cliente Firebase esperada para Android; no es una clave privada de firma ni una service-role de Supabase.

## Validación manual requerida antes de continuar

- PC navegador: orden, apertura/cierre de Mi Club y cambio de ruta.
- Móvil navegador/PWA: botón de menú, bottom-nav y áreas táctiles.
- Dirección/Coordinación: Mi perfil abre identidad personal; Perfil del club permanece dentro de Mi Club.
- Alumno/Monitor/Economía: comprobar que no se ha perdido ningún acceso por rol.
- Simular mala conexión y recuperación sin logout.
- Forzar sesión caducada/refresh token inválido y verificar mensaje humano sin texto técnico.

## Pendientes deliberados

- Cabecera completa: Notificaciones KOMBAX / Notificaciones del Club / Mensajes con contadores reales.
- Push: mantener únicamente Mi Club en MVP y verificarlo al separar canales.
- 20.059: Mi red KOMBAX, Contact Gate, chat realtime ilimitado/paginado, Social vs Showcase, comentarios inline y respuestas.

**No declarar freeze con este paquete sin validación manual.**
