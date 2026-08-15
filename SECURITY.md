# Seguridad · Urban Warriors RC13 build 20018

## Autoridad

- El frontend no contiene `service_role`.
- Auth real + `Authorization` de sesión.
- Todas las mutaciones de negocio pasan por `app_mutate_v160` y `request_id` idempotente.
- El cliente valida backend `1.6.0`, schema epoch `160` y operaciones requeridas antes de escribir.
- Permisos visuales no sustituyen las comprobaciones SQL.

## Tenant y privacidad

- Los recursos de club conservan `club_id` y validación de membresía/rol.
- Perfil deportivo, perfil público de club e identidad social son capas distintas.
- El perfil público del club no se alimenta de CIF, email/teléfono administrativos ni dirección privada.
- Fecha de nacimiento, finanzas, documentos y parentesco no se copian a la identidad social.

## 034 · Notificaciones

- la lectura masiva/grupo no puede ocultar avisos accionables;
- una lectura individual simple también rechaza una tarea accionable;
- `notificacion.revisar` exige acceso al aviso y deja `perfil_id`, ruta y timestamp;
- el cliente móvil muestra las tareas separadas de informativas.

## 035 · Perfil público

- tabla sin SELECT directo para `authenticated`;
- lectura mediante RPC explícita;
- edición solo Dirección o Coordinación por gateway;
- slug validado y estable;
- enlaces, logo y portada públicos se restringen a `https://` tanto en el gateway como mediante constraints; el seed descarta URLs administrativas no HTTPS;
- nombre del club, no el logo, es el punto de navegación exigido en Comunidad interna.

## 036 · Edad / social / UGC

- autorregistro alumno 16+ verificado en backend;
- elegibilidad social se calcula desde socio `activo`, DOB almacenada por club y rol `alumno`; el umbral vive en `config_club.edad_min_comunidad_general` con suelo técnico de producto en 14 años;
- familia/tutor no activa la capa social;
- normas y privacidad deben aceptarse y quedan versionadas;
- publicar UGC en la Comunidad interna exige aceptación explícita y vigente de sus normas; crear la cuenta del club no las acepta automáticamente;
- denuncia/bloqueo sin DML directo;
- reportes solo visibles por RPC a moderadores autorizados;
- suspender/reactivar acceso social requiere motivo, no puede hacerse sobre uno mismo y deja una fila de auditoría;
- el usuario suspendido/cerrado no puede auto-reactivar su identidad.

## Android

- `usesCleartextTraffic=false`;
- package estable `com.urbanwarriors.app`;
- target/compile SDK 36;
- firma release mediante secretos externos al repositorio.

## Pendiente antes de afirmar producción

034–036 deben verificarse en Supabase real, luego probarse con cuentas reales por rol/RLS y en APK física. La presencia de denuncia/bloqueo/moderación no constituye por sí sola aprobación de Google Play: todavía hay que completar público objetivo, privacidad/Data Safety y requisitos de UGC/seguridad infantil en Play Console.
