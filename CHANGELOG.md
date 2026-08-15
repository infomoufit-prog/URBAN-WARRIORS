# Changelog

## 2.0.0-rc.13 · build 20020 · corrección de próxima sesión en portal alumno

- Portal alumno/familia: la **próxima sesión** permanece visible y accionable aunque caiga en la semana siguiente; corrige el caso detectado el sábado 15/08 con una clase del martes 18/08.
- Dashboard alumno: permite **Confirmar asistencia** o **Cancelar asistencia** directamente sobre la próxima actividad; el check-in sigue apareciendo solo el día de la clase.
- Vista semanal: se conserva `Esta semana / anterior / siguiente`; si la semana actual está vacía, la próxima sesión no desaparece porque queda fijada arriba.
- Backend/Supabase: **sin cambios SQL**; 034–036 permanecen exactamente como en build 20019.
- Android/web: build incrementado a `20020` para no confundir el paquete corregido con 20019.

## 2.0.0-rc.13 · build 20019 · pulido final previo a validación del club

- UX: la red interna pasa a llamarse **Comunidad del Club**; la futura capa global se presenta como **Social Community / Comunidad General**.
- Sesiones: vista por semana natural (lunes–domingo), navegación anterior/actual/siguiente y prioridad visual para la próxima sesión; no cambia el motor de recurrencias ni el histórico.
- Portal alumno/familia: las sesiones se consultan con la misma organización semanal.
- Branding: logos de club recortados en marco circular; PWA añade iconos maskable y Android añade adaptive icon para evitar el recuadro dentro del launcher circular.
- Android/web: `versionCode`/cache build 20019; `applicationId` y `versionName` se conservan para continuidad de actualización.
- Backend: **sin migraciones nuevas**; 034–036 permanecen sin cambios.
- Regresión local: 57/57 JS/MJS, 583 `OK`, 29 `PASS`, contrato 93/93 y `web = dist = Android` con 51 archivos.

## 2.0.0-rc.13 · build 20018 · intervención final del MVP

- 034: notificaciones accionables; lectura masiva solo informativa y revisión auditada.
- 035: perfil público de Urban Warriors separado de datos administrativos; el nombre del club en Comunidad abre la ficha; URLs públicas restringidas a HTTPS desde tabla, seed, gateway y render.
- 035: capa normalizada de identidad/búsqueda `club + miembro`, preparada para futuros tipos.
- 036: autorregistro autónomo alumno 16+ y elegibilidad social desde dato de edad verificado por el club; umbral social configurable en backend con suelo 14.
- 036: Comunidad General opcional, sin feed global en esta fase; familia/tutor no crea identidad social.
- 036: la Comunidad interna deja de considerar aceptadas sus normas durante el alta; publicar UGC exige aceptación explícita y vigente, comprobada también por backend.
- 036: denuncia, bloqueo, resolución/ocultación y suspensión/reactivación social con auditoría.
- Android: build 20018, compile/target SDK 36 y AGP 8.10.1; applicationId conservado.
- Las migraciones 031–033 ya fueron verificadas en Supabase real; 034–036 siguen pendientes de ejecución real.
- No es freeze ni producción hasta cerrar Supabase, roles/RLS, APK física y distribución.

## 2.0.0-rc.13 · MVP Freeze candidate (implementado localmente)

- Build 20017; RC12 permanece como punto de retorno y no se sobrescribe.
- Corregida la contaminación responsive móvil→PC con guardias explícitas de escritorio.
- Finanzas: preservada separación cuota/material/otro; añadido test matemático y runbook estricto para 031 pendiente en Supabase real.
- Comunidad: likes con contador anónimo; identidad no consultable por otros usuarios.
- Perfil deportivo por socio, editable por titular/tutor, visible solo en el mismo club y separado de datos administrativos.
- Privacidad voluntaria y bloqueo por moderación modelados de forma independiente.
- Nueva sección Eventos/Competiciones con requisitos, inscritos internos/externos, aprobación y combates manuales.
- Participantes externos no requieren app/cuenta y no almacenan datos de contacto innecesarios.
- Lecturas sensibles de perfiles/participantes/combates mediante RPCs seguras; DML nuevo exclusivamente por gateway.
- Contrato frontend exige las 12 capacidades nuevas antes de aceptar el backend RC13.
- Nuevas migraciones 032/033, preflights, verificaciones y rollbacks conservadores.
- Regresiones RC4–RC12 y suites RC13 integradas en `npm test`.
- No se considera congelada hasta certificar Supabase real + PC/web móvil + APK física.

## Release J — multiclub, RLS y rendimiento (implementado localmente)

- Auditoría confirma `club_id` en todos los recursos de negocio; perfiles permanecen globales deliberadamente.
- Dispositivos push y preferencias exigen usuario propio y pertenencia activa al club.
- Lecturas de notificación solo pueden referirse a avisos visibles para el usuario.
- DML directo cerrado en recursos críticos; privilegios previos quedan fotografiados para rollback exacto.
- Índices compuestos añadidos para socios, sesiones, comunicaciones, materiales, push y notificaciones.

## Release I — vídeos y portadas (implementado localmente)

- Vídeos de hasta 50 MB y 15 segundos, con validación máxima 1080p horizontal o vertical.
- Portada WebP automática extraída antes de subir el vídeo.
- Portada manual inicial y acción `Cambiar portada` limitadas a Gestor/Coordinación.
- Feed con `preload="none"`, poster firmado e imágenes diferidas.
- Migración 029 amplía el bucket privado y conserva paths de portada; el worker de caducidad limpia los tres archivos.

## Release H — imágenes optimizadas (implementado localmente)

- Originales de hasta 35 MB se redimensionan a un máximo de 1920 px y salida menor de 5 MB.
- WebP progresivo con fallback compatible y liberación explícita de memoria.
- Optimización compartida por Comunidad, Comunicaciones, Materiales y personalización.
- Migración 028 añade únicamente MIME, dimensiones y peso; los binarios continúan en Storage.
- Las subidas dejan de esperar indefinidamente y presentan un error comprensible.

## Release G — Comunidad escalable (implementado localmente)

- Feed paginado mediante cursor estable `(creado_en, id)` y bloques máximos de 20.
- Carga progresiva al aproximarse al final, con botón manual como alternativa accesible.
- Índice multiclub 027 alineado con club, estado y orden del feed.
- La apertura de Comunidad deja de descargar el histórico completo.

## Release F — material, validación, deuda y avisos (implementado localmente)

- Migración 025: retirada pendiente, validación atómica, stock, entrega y cargo financiero relacionado.
- Alumno/familia no puede validar ni modificar precio; equipo autorizado puede registrar pendiente o validar directamente.
- Idempotencia por `request_id`, `origen_id` único y devolución segura ante una segunda validación.
- Migración 026: cuotas y material comparten el mismo motor e historial de avisos, con mensajes individuales o agrupados.
- Rollbacks conservadores para gateway y motor de recordatorios.

## Release E — historial y métricas financieras (implementado localmente)

- Añadida migración no destructiva `024_finance_annual_metrics.sql` y rollback conservador.
- Historial filtrable por año, mes, alumno, origen y estado con consultas filtradas en Supabase.
- Métricas mensuales/anuales derivadas de cuotas y pagos validados, sin tabla contable duplicada.
- Vista alumno/familia simplificada: total pendiente, conceptos, pagos y recibos propios.
- Preparado el origen `cuota/material/otro` para la integración atómica de Release F.

## Release D — permiso global y avisos de cobro (implementado localmente)

- Eliminadas de la experiencia las categorías push personales; Android conserva el permiso global.
- Los dos workers FCM dejan de filtrar por preferencias individuales y siguen limitados a dispositivos activos.
- Los tokens FCM inválidos se desactivan también desde `payment-reminders`.
- Preservados cinco días configurables del 1 al 28, hora, activo, vencimiento, proceso manual, historial e idempotencia.
- Sin cambios destructivos ni migración SQL; la tabla histórica de preferencias permanece por compatibilidad.

## Release C — Firebase Android seguro y onboarding (implementado localmente)

- Firebase deja de ser una dependencia crítica del arranque.
- Token FCM asíncrono, renovable y comunicado al frontend.
- Añadidos estados de permiso, explicación y acceso a Ajustes Android.
- Errores de inicialización, token o permiso quedan en Logcat sin cerrar la app.

## Release B — safe areas Android (implementado localmente)

- Añadida detección nativa de barras del sistema y recorte de pantalla.
- Añadido contrato CSS compartido para safe area superior e inferior.
- Protegidas cabecera, navegación, contenido, menús, modales, login y avisos flotantes.
- Sin cambios en Supabase, Firebase, RLS o funciones de negocio.

## Baseline recovery 023 — desplegado y validado

- Detectado gateway de producción distinto del RC10 final.
- Localizada la copia íntegra RC10 en `app_mutate_v160_v166`.
- Añadida migración reversible para recuperar el gateway sin modificar datos.
- Añadido test estático específico y punto de rollback.
- Ejecutado en Supabase real con resultado 12/12 OK.
- Certificación E2E real superada: 19/19.
- Vista previa web RC10 certificada: diagnóstico 12/12 y CRUD crítico de Comunidad, Comunicaciones, Materiales y Finanzas.
- Registrada incidencia no bloqueante de subida de imágenes grandes en `BUGS.md`.

## 2.0.0-rc.10

- Base estable recibida y congelada como punto de retorno.

## Paquete de certificación previo a despliegue

- Añadidos controles de solo lectura antes y después de las migraciones 029 y 030.
- Añadida auditoría conjunta de estructura y cadena de gateways 023–030.
- Añadida consulta de salud backend previa a APK sin exponer tokens.
- Documentado el orden Supabase → Edge Functions → CRUD/RLS → Android/Pixel 8 → Netlify.
- Alineado el snapshot 030 con todos los recursos auditados para que el rollback de privilegios sea completo.
