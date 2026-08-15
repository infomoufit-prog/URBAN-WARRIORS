# Urban Warriors RC13 build 20018 · Informe final de implementación local

## 1. Identificación

- Base de trabajo: **Urban Warriors RC13 build 20017**.
- Candidata resultante: **2.0.0-rc.13 / build 20018**.
- `applicationId`: `com.urbanwarriors.app`.
- Backend esperado: `1.6.0`.
- Schema epoch: `160`.
- Base Git de referencia: commit `b46fe99` (`RC13 build 20017 baseline`).
- Estado Git: cambios deliberadamente **sin commit/tag de freeze** hasta completar Supabase real y prueba física.

La RC13 build 20018 se ha tratado como una candidata nueva sobre la build 20017, no como un parche improvisado sobre producción.

## 2. Regla de alcance

La aplicación sigue siendo **Urban Warriors** y sigue validándose como MVP de un único club. No se ha desplegado todavía un entorno multiclub visible, selector de clubes, rebranding general ni Comunidad General completa.

Sí se han fijado reglas de evolución para evitar cerrar la arquitectura:

- Urban Warriors no se convierte en una excepción hardcodeada de las nuevas funciones.
- Datos administrativos y perfiles públicos quedan separados.
- El perfil público del club se diseña como modelo generalizable.
- La futura capa social es opcional e independiente de la gestión del club.
- Los tipos futuros (competidor, federación, marca, tienda) quedan fuera del alcance funcional actual.

Documento permanente: `PLATFORM_EVOLUTION_RULES.md`.

## 3. Fase 1 · 034 Notificaciones accionables — IMPLEMENTADA LOCALMENTE

### Backend / SQL

Nueva migración:

- `supabase/migrations/034_notifications_actionable.sql`
- `supabase/verification/preflight_034_notifications.sql`
- `supabase/verification/verify_034_notifications.sql`
- `supabase/verification/test_034_notifications_transactional.sql`
- `supabase/rollbacks/034_notifications_actionable.sql`

Se incorpora:

- `notificaciones_revisiones` para auditoría de revisión;
- `app_notificacion_requiere_accion_v034`;
- `app_notificaciones_accionables_v034`;
- operación contractual `notificacion.revisar`;
- endurecimiento de `notificacion.leer`, `notificacion.leer_grupo` y `notificacion.leer_todas`.

La clasificación consulta el **estado vivo** del objeto cuando existe relación con preinscripción, pedido de material, pago o cuota. Ya no se asume que todo aviso de un tipo determinado sigue requiriendo acción.

### Semántica de lectura

- las informativas sí pueden limpiarse en masa;
- una accionable no puede marcarse simplemente como leída;
- lectura global/grupal excluye accionables;
- `Revisar` deja trazabilidad y permite cerrar la lectura de la acción.

### Frontend / APK

- texto principal: `Marcar informativas como leídas`;
- el bloque `Requiere acción` no ofrece lectura masiva;
- una accionable muestra `Revisar`;
- bandeja ampliada y contenido adicional accesible mediante `<details>` para evitar que el corte visual esconda avisos;
- reglas responsive específicas para móvil.

### Prueba transaccional

La prueba 034 cubre tanto lectura masiva global como lectura masiva de grupo, demuestra que las accionables sobreviven a ambas, que la lectura simple se rechaza y que `revisar` marca/audita. Los datos de prueba se revierten mediante subtransacción controlada.

**Estado real Supabase: PENDIENTE DE APLICAR.**

## 4. Fase 2 · 035 Perfil público del club — IMPLEMENTADA LOCALMENTE

Nueva migración:

- `supabase/migrations/035_club_public_profile.sql`
- `supabase/verification/preflight_035_club_public_profile.sql`
- `supabase/verification/verify_035_club_public_profile.sql`
- `supabase/rollbacks/035_club_public_profile.sql`

### Modelo

Tabla `perfiles_club_publicos`, separada de `clubes` administrativos, con:

- slug;
- nombre público;
- alias;
- lema;
- descripción/historia;
- ciudad/provincia/país;
- logros;
- contacto público voluntario;
- web y redes;
- logo/portada;
- visibilidad y moderación.

No se copia al perfil público CIF, email administrativo, teléfono administrativo, dirección privada u otros campos privados.

### URLs públicas

Se ha endurecido el modelo en dos niveles:

- constraints SQL: las URLs públicas no vacías deben ser `https://`;
- gateway: rechaza esquemas distintos de HTTPS antes de guardar;
- frontend: vuelve a sanear antes de usar `href`, `src` o fondos.

El seed actual/futuro descarta URLs administrativas no HTTPS.

### Navegación acordada

Dentro de Comunidad interna, el acceso se realiza desde el **nombre del club**, no desde el logo. El nombre abre la ficha pública que posteriormente podrá reutilizarse en una capa social general.

**Estado real Supabase: PENDIENTE DE APLICAR.**

## 5. Fase 3 · Capa normalizada de identidad/búsqueda — IMPLEMENTADA LOCALMENTE

RPC `app_buscar_identidades_publicas_v035` normaliza por ahora:

- `club`;
- `miembro` con perfil deportivo visible.

Devuelve un contrato común de identidad para frontend sin fusionar entidades heterogéneas en una tabla gigante. La búsqueda contempla datos públicos y también disciplina/grupo cuando corresponde.

En RC13 no se expone todavía un directorio multiclub global: se valida la arquitectura dentro del club actual.

## 6. Fase 4 · 036 Base opcional de Comunidad General — IMPLEMENTADA LOCALMENTE

Nueva migración:

- `supabase/migrations/036_social_access_safety_age.sql`
- `supabase/verification/preflight_036_social_access.sql`
- `supabase/verification/verify_036_social_access.sql`
- `supabase/rollbacks/036_social_access_safety_age.sql`

### Alta social independiente

Se incorpora `identidades_sociales` como identidad social opcional del miembro. Tener cuenta del club no activa automáticamente esta capa.

Estados previstos:

- activa;
- suspendida;
- cerrada.

La relación al socio operativo es nullable y `ON DELETE SET NULL`; el histórico social no bloquea la baja administrativa del socio. Se conserva `club_origen_id`.

### Edad social configurable

- se crea `config_club.edad_min_comunidad_general` con 14 como valor inicial;
- el backend impone siempre un suelo de 14 y techo defensivo 99;
- la nueva función `app_edad_min_comunidad_general_v036` lee el valor defensivamente: una configuración malformada no rompe el perfil/login ni rebaja el suelo;
- `verify_036` comprueba que todos los clubes tengan configuración numérica válida 14–99;
- elegibilidad se calcula con el socio **activo** y su fecha de nacimiento validada por el club;
- solo rol `alumno` puede activar en esta fase;
- familia/tutor no recibe esta activación.

La RC no construye todavía el feed global.

**Estado real Supabase: PENDIENTE DE APLICAR.**

## 7. Fase 5 · Autorregistro alumno 16+ — IMPLEMENTADA LOCALMENTE

Se mantiene el flujo histórico de cuenta + preinscripción; no se añade una capa paralela de afiliaciones.

### UX

La entrada comunica:

`Tengo 16 años o más y quiero inscribirme como alumno`

La fecha de nacimiento pasa a ser obligatoria para el autorregistro de alumno.

### Backend

`cuenta.registrar` queda interceptada por 036 antes de delegar al flujo histórico:

- fecha obligatoria;
- fecha futura rechazada;
- edad <16 rechazada;
- 16+ continúa por el sistema existente.

Por tanto, manipular el frontend no permite saltarse el umbral.

## 8. Fase 6 · Seguridad UGC y moderación — IMPLEMENTADA LOCALMENTE

Objetos/operaciones:

- `bloqueos_comunidad`;
- `reportes_comunidad`;
- `moderacion_accesos_sociales`;
- `comunidad.denunciar`;
- `comunidad.bloquear`;
- `comunidad.denuncia.estado`;
- `comunidad_general.moderar_acceso`.

Incluye:

- denunciar publicación;
- denunciar perfil;
- bloquear/desbloquear;
- resolución de denuncias;
- ocultación de publicación desde moderación;
- suspensión/reactivación social con motivo;
- historial de moderación;
- motivo `sexual_menores` entre los motivos de seguridad.

### Normas UGC internas

Se corrigió un comportamiento histórico importante: el registro del club **ya no registra silenciosamente la aceptación de las Normas de Comunidad**.

Ahora:

1. el usuario intenta publicar;
2. se comprueba la versión vigente de las normas;
3. si no están aceptadas, se muestra el texto y un `Aceptar y continuar` explícito;
4. la aceptación queda registrada;
5. el backend rechaza una publicación nueva sin aceptación vigente;
6. una revocación bloquea nuevas publicaciones sin eliminar la cuenta de gestión;
7. la idempotencia de una mutación ya completada se conserva.

## 9. Fase 7 · Contrato, RLS, seguridad y documentación — IMPLEMENTADA LOCALMENTE

El contrato frontend final exige 19 operaciones RC13 añadidas entre 032–036.

La suite de contrato encuentra **93/93 operaciones de `app_mutate_v160` implementadas** en el gateway encadenado.

034 → 035 → 036 preservan expresamente gateway y runtime contract previos mediante funciones `pre_*`, con rollback por fase.

Se han actualizado documentos de arquitectura, base de datos, permisos, RLS, seguridad, roadmap, estado, Android, runbook y validación.

No se concede SELECT directo al cliente sobre tablas sensibles nuevas cuando la lectura requiere RPC segura.

## 10. Fase 8 · Regresión automática — COMPLETADA LOCALMENTE

### Sintaxis

`node --check` ejecutado sobre **56/56** archivos JS/MJS de `web/js` y `scripts`.

Resultado: **0 fallos**.

Log: `Urban_Warriors_RC13_BUILD_20018_NODE_CHECK.log`.

### Suite completa

`npm test` final:

- **612** líneas de comprobación `OK`;
- **28** marcadores `PASS`;
- contrato: **93/93** operaciones `app_mutate_v160` implementadas;
- regresiones RC4–RC12 incluidas;
- RC13 031–033 incluidas;
- nuevas suites 034, 035, 036 y Android/Play estático incluidas.

Log: `Urban_Warriors_RC13_BUILD_20018_TEST.log`.

### Build

`npm run build` final: **PASS**.

Resultado:

`OK build 49 archivos · web = dist = Android`

Log: `Urban_Warriors_RC13_BUILD_20018_BUILD.log`.

### Integridad final

- `diff -qr web dist`: sin diferencias;
- `diff -qr web android/app/src/main/assets/www`: sin diferencias;
- `git diff --check`: limpio;
- sin `requiredOperations=[]`;
- sin `0.0.0.0` en servidor/assets;
- sin `service_role` en cliente;
- `scripts/serve.mjs`: `127.0.0.1`;
- configuración/index/service-worker/Gradle coherentes con build 20018.

## 11. Fase 9 · Preparación Android build 20018 — COMPLETADA SOLO A NIVEL DE CÓDIGO/CONFIGURACIÓN

Configurado:

- `versionCode 20018`;
- `targetSdk 36`;
- `compileSdk 36`;
- AGP `8.10.1`;
- Java source/target 17;
- `applicationId` estable;
- firma release mediante variables de entorno, sin secretos embebidos;
- `usesCleartextTraffic=false`.

Este entorno no contiene Android SDK, Gradle instalado ni Gradle Wrapper completo. Por tanto:

- **APK release no compilada aquí**;
- **AAB no compilado aquí**;
- **firma real no certificada aquí**.

Véase `ANDROID_PLAY_READINESS_RC13_BUILD_20018.md`.

## 12. Fase 10 · Supabase real + pruebas físicas — NO COMPLETADA

Estado live conocido:

- 031 Finanzas: certificada previamente;
- 032 perfil deportivo/likes: certificada previamente;
- 033 Eventos: certificada previamente;
- 034: pendiente;
- 035: pendiente;
- 036: pendiente.

Debe ejecutarse en orden estricto:

1. preflight 034;
2. aplicar 034;
3. verify + transaccional 034;
4. preflight/aplicar/verify 035;
5. preflight/aplicar/verify 036;
6. roles/RLS reales;
7. PC/móvil web;
8. APK física 20018 instalada encima de la build previa.

No se debe desplegar Netlify antes de cerrar esta fase.

## 13. Fase 11 · Freeze / distribución — NO COMPLETADA

No se ha hecho commit/tag de freeze ni despliegue final.

Pendiente:

- APK release firmada;
- AAB;
- prueba de actualización in-place;
- prueba física por roles;
- push/foreground/background;
- revisión de Play Console;
- Data Safety/política de privacidad;
- diseño y recurso de eliminación de cuenta si corresponde a la publicación;
- público objetivo y seguridad infantil;
- freeze desde SHA exacto;
- Netlify final solo desde el mismo estado certificado.

## 14. Resultado de la intervención

**Fases 1–8: implementadas y certificadas localmente.**

**Fase 9: código/configuración Android completados; build nativa pendiente por ausencia del toolchain.**

**Fases 10–11: deliberadamente pendientes de ejecución real; no se presentan como completadas.**

La candidata está lista para iniciar el runbook real por **preflight 034**, no para saltar directamente a producción.
