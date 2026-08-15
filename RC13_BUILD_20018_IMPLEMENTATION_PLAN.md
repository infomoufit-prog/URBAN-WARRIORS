# Urban Warriors RC13 · Plan de intervención final · build 20018

## 0. Punto de partida y regla de alcance

Base técnica: RC13 build 20017. Las migraciones 031, 032 y 033 ya forman parte de la cadena actual y no se reabren salvo compatibilidad estrictamente necesaria.

Esta intervención NO crea todavía la plataforma multiclub completa ni cambia el nombre/branding de Urban Warriors. Urban Warriors sigue siendo el entorno único de validación del MVP. Sí se dejan decisiones, claves y modelos preparados para poder generalizar después sin rehacer el producto.

Reglas permanentes:
- no hardcodear reglas de negocio que solo funcionen para Urban Warriors;
- mantener `club_id` y RLS en toda información tenant cuando corresponda;
- separar expediente privado, perfil deportivo compartido y futuras identidades públicas/sociales;
- mantener Comunidad interna y futura Comunidad General como ámbitos distintos;
- toda escritura nueva pasa por gateway/RPC y contrato;
- PC, web móvil y APK deben ofrecer las mismas funciones; solo cambia layout;
- cada fase debe añadir pruebas automáticas y verificación SQL antes de avanzar;
- después del build 20018: freeze funcional, solo bugs/correcciones.

## Fase 1 · 034 Notificaciones accionables y limpieza masiva segura

### Problema auditado
El centro actual ya tiene lectura individual, por grupo y “Marcar todo leído”. La clasificación “Requiere acción” se basa principalmente en tipos y la operación masiva puede marcar también avisos que deberían obligar a revisar una tarea.

### Objetivo
Permitir que especialmente los roles de equipo limpien ruido sin ocultar tareas pendientes.

### Backend / SQL
Crear `supabase/migrations/034_notifications_actionable.sql` encadenada después de 033.

- definir una clasificación backend/derivada de `requiere_accion` basada en propósito + estado real;
- introducir una operación masiva segura, por ejemplo `notificacion.leer_informativas`;
- impedir que lectura masiva marque como leídas notificaciones pendientes de acción;
- conservar `notificacion.leer` para lectura individual;
- las notificaciones accionables solo pasan a leídas cuando se abre/revisa su ruta o mediante una mutación explícita segura ligada a revisión;
- mantener soporte de avisos compartidos mediante `notificaciones_lecturas`;
- no borrar notificaciones como parte de “leer”.

### Frontend
Actualizar `web/js/modules/comms-material.js`:
- “Marcar todo leído” pasa a “Marcar informativas como leídas”;
- eliminar acción masiva de lectura en el bloque “Requiere acción”;
- avisos accionables muestran `Ver` / `Revisar`, no un simple `Leída`;
- avisos informativos sí permiten lectura individual y por grupo;
- mejorar móvil/APK para que el botón masivo sea visible y usable;
- mantener contador correcto de campana.

Actualizar `web/js/core/repositories.js`, contrato requerido y tests.

### Aceptación
Caso mínimo: 20 informativas + 3 accionables -> acción masiva -> 20 quedan leídas, 3 permanecen pendientes hasta revisión.

## Fase 2 · 035 Perfil público de Urban Warriors como modelo generalizable

### Objetivo
Crear dentro del MVP actual una ficha pública de Urban Warriors que valide la estructura que después podrá generalizarse a otros clubes.

### Backend / SQL
Crear `supabase/migrations/035_club_public_profile.sql`.

Modelo separado de datos administrativos, vinculado por `club_id`, con campos públicos controlados:
- nombre público;
- alias/nombre corto;
- slug público estable;
- logo/portada cuando corresponda;
- descripción;
- lema;
- disciplinas/resumen deportivo;
- ciudad/provincia/país públicos;
- historia/logros;
- enlaces/redes/contacto público voluntario;
- visible;
- moderación/estado cuando corresponda;
- trazabilidad de actualización.

La dirección, email administrativo, teléfonos privados, finanzas, documentos y datos internos nunca se exponen por esta ficha.

Añadir RPC de lectura segura y mutación de edición para roles autorizados. La estructura tendrá `club_id` y será generalizable, aunque en RC13 solo se use Urban Warriors.

### Frontend
- nueva vista/modal de perfil público de club;
- dentro de Comunidad interna, el NOMBRE “Urban Warriors” es el elemento navegable que abre el perfil;
- el logo no es el mecanismo obligatorio de navegación;
- la ficha será reutilizable en la futura Comunidad General;
- edición solo para rol autorizado.

## Fase 3 · Capa de identidad pública preparada, sin construir la red social global

### Objetivo
Preparar una interfaz común para perfiles públicos sin convertir todo en una tabla única.

Mantener modelos separados:
- perfil deportivo;
- perfil público de club;
- futuros competidor, federación, marca y tienda.

Crear una forma normalizada de lectura/búsqueda con:
- id público;
- tipo de identidad;
- nombre;
- avatar/logo;
- subtítulo;
- slug/referencia.

En RC13 solo se conectan perfil deportivo permitido + perfil público de Urban Warriors. No se despliega aún directorio multiclub real.

## Fase 4 · 036 Base de alta opcional para futura Comunidad General

### Alcance
No se construye todavía el feed global. Se prepara la capa de acceso social separada del club.

### Reglas
- usar Urban Warriors normalmente NO implica estar dado de alta en la Comunidad General;
- la Comunidad General tendrá registro/activación propia;
- el expediente administrativo no se convierte en perfil público automáticamente;
- padre/tutor no accede ni publica en Comunidad General;
- la edad se calcula con fecha de nacimiento verificada por el club, nunca con una autodeclaración del frontend;
- umbral social actual de diseño: 14+; debe quedar parametrizable/configurable en backend antes de producción global;
- la activación social es voluntaria y requiere aceptar normas/términos específicos;
- estados previstos: no activado / activo / suspendido (y pendiente solo si realmente aporta valor al flujo final).

### Importante
El MVP actual no da cuenta independiente a menores. Por tanto, RC13 solo debe dejar lista la elegibilidad/modelo social; no se abrirá un acceso social real 14-15 sin diseñar previamente un mecanismo de identidad/credenciales independiente y seguro.

## Fase 5 · Autorregistro del club desde 16 años

### Objetivo
Mantener el sistema actual de preinscripción, pero cambiar la regla de autorregistro autónomo.

- tipo alumno/autoregistro: fecha de nacimiento obligatoria;
- 16 años cumplidos o más: puede crear su cuenta y enviar su preinscripción;
- menor de 16: no puede usar el flujo autónomo de alumno; su alta continúa mediante tutor/club;
- el control se valida también en backend, no solo en interfaz;
- texto de UI: “Tengo 16 años o más y quiero inscribirme como alumno”, evitando confundirlo con mayoría de edad de 18.

No crear una nueva “solicitud de afiliación”: se conserva el modelo actual de cuenta + preinscripción.

## Fase 6 · Moderación y cumplimiento de la futura capa social

Preparar estructura y operaciones necesarias para que una futura Comunidad General no nazca sin gobernanza:
- denunciar publicación;
- denunciar perfil/usuario;
- bloquear identidad/usuario;
- moderar/ocultar contenido;
- suspender acceso social;
- motivo, autor de moderación y timestamps de auditoría;
- normas/versionado de aceptación.

En RC13 se implementa la base backend/UI mínima que sea útil para la distribución del MVP actual, sin construir seguidores, chat, contactos ni feed global.

## Fase 7 · Contrato, seguridad y documentación

Actualizar:
- `ARCHITECTURE.md`;
- `DATABASE.md`;
- `SECURITY.md`;
- `RLS_MATRIX.md`;
- `MATRIZ_PERMISOS.md`;
- `ROADMAP.md`;
- `CHANGELOG.md`;
- `STATUS.md`;
- `RC13_VALIDATION.md`;
- `ANDROID.md` cuando corresponda.

Encadenar 034 -> 035 -> 036 sobre 033 y actualizar `app_runtime_contract_v160` / `app_mutate_v160` sin romper operaciones previas.

Añadir preflight, verify y rollback por cada migración nueva.

## Fase 8 · Pruebas automáticas y regresión

Añadir suites específicas:
- notificaciones accionables;
- perfil público de club;
- privacidad del perfil público;
- regla de autorregistro 16+;
- elegibilidad social configurable;
- moderación/bloqueo/denuncia si quedan activos en RC13;
- contrato y cadena SQL 031-036;
- responsive PC/móvil de nuevas pantallas.

Reejecutar toda la suite histórica RC4-RC13.

Criterios mínimos:
- `npm test` PASS;
- `node --check` de JS/MJS PASS;
- `git diff --check` PASS;
- no regresión 031/032/033;
- controles RLS/tenant PASS.

## Fase 9 · Build 20018 y paridad

Incrementar:
- RC13 build 20017 -> 20018;
- Android `versionCode` -> 20018;
- cache/service worker/manifiestos/URLs de assets coherentes.

Antes del build final:
- revertir `scripts/serve.mjs` a `127.0.0.1` si en local sigue el cambio temporal a `0.0.0.0`;
- eliminar cualquier bypass temporal de desarrollo;
- build limpio;
- verificar `web = dist = android/app/src/main/assets/www`.

## Fase 10 · Supabase real y pruebas físicas

Orden obligatorio:
1. backup;
2. preflight 034;
3. aplicar 034;
4. verify/transaccional 034;
5. preflight/aplicar/verify 035;
6. preflight/aplicar/verify 036;
7. pruebas manuales por roles/RLS;
8. PC y web móvil;
9. APK release en dispositivo físico;
10. instalar build 20018 encima de la versión anterior sin desinstalar;
11. notificaciones, foreground/background, navegación y permisos Android.

## Fase 11 · Freeze y preparación de distribución

Cuando todo lo anterior pase:
- cero funciones nuevas;
- solo correcciones de bugs con regresión;
- generar APK release de pruebas;
- preparar AAB release para Google Play;
- revisar firma, `applicationId`, versión, target SDK/políticas vigentes, privacidad/Data Safety y requisitos de UGC antes de publicación;
- commit/tag desde el SHA exacto certificado;
- Netlify solo al final desde ese mismo estado.

## Fuera de alcance de RC13 build 20018

No implementar ahora:
- plataforma multiclub visible/selector de clubes;
- rebranding/nombre general de plataforma;
- Comunidad General completa/feed global;
- seguidores/amigos;
- chat/mensajería;
- perfiles funcionales de competidor independiente, federación, marca o tienda;
- marketplace;
- brackets automáticos;
- relaciones sociales multientidad.

La arquitectura sí debe quedar preparada para añadirlos después sin rehacer 031-036.
