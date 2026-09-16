## R79 · build 20130 · i18n completion phases 6–10

- Completed strict system-copy localization audit across the remaining Finance, Admin, profiles/entities, support/legal and residual operational surfaces.
- Added 607 R79 audited source strings with 7 non-Spanish translations (EN/FR/PT/IT/DE/TH/FIL), preserving Spanish as source of truth.
- Added R79 exact/dynamic runtime precedence above R78 while preserving user-generated content boundaries.
- Global strict product audit reaches 0 unresolved system-copy candidates after explicit technical-code exclusions.
- R78 phase 1–5 catalog remains intact and cumulative.


## R78 · build 20129 · i18n phases 1–5
- Replaced key-only localization confidence with an audited visible-system-copy catalog.
- Added 1,086 fixed system strings with complete EN/FR/PT/IT/DE/TH/FIL precomputed translations.
- Added exact + dynamic R78 runtime precedence and persistent locale cache.
- Preserved UGC original-text boundaries and all R75/R77 functionality.
# R40 · 2026-09-04

- Mi red: descriptor `Contactos y conexiones KOMBAX` + CTA `Añadir a mi red`.
- Social: Mi red, clubes seleccionados y exclusiones de clubes sin romper conexiones.
- Events: visibilidad pública/KOMBAX/red/club/clubes/Federación/invitación.
- Migrations: banners adicionales en Federaciones/licencias y Archivo documental.
- Auditoría de Marca R37 confirmada.
- Backend R40 aplicado live; sin Netlify/GitHub/Google Play/firma Android.

# R39 · 2026-09-04

- Reordenación del acordeón Mi Club.
- Asistencia virtual + Migrations + Manual agrupados.
- Mis licencias integrado dentro de Federaciones y licencias.
- Promoción contextual directa de KOMBAX Migrations.

# 20.101 R38 · Assist + Migrations Economy

- KOMBAX Assist separado: email-first y chat guiado únicamente cuando soporte lo activa.
- KOMBAX Migrations separado: acceso directo, conversación + carga de documentos en el mismo caso.
- Confirmación humana obligatoria antes de cualquier importación.
- Ledger privado, límites de coste/turnos/documentos y enrutamiento interno económico.
- Backend 227–234 aplicado live; Edge Function `kombax-assist-r38` live.
- R38 67/67; full build exit 0; web/dist/Android 189/189/189 sin diferencias.
- Android preflight 4/5; firma local fuera del paquete.

# 20.101 R35 · Event-Centric Competition Preparation

- Preparación ligada a inscripción concreta, sin nueva capa permanente en Mi Club.
- KOMBAX Events + eventos internos comparten seguimiento y pesaje oficial.
- `Mis competiciones` para Competidor/miembro.
- Histórico privado separado del organizador/federación.
- Pesaje oficial bloqueado como dato del evento.
- Backend 218/219 aplicado live; build 186/186/186 PASS.

# 20.101 R3 · Event Visual Editor Hardening

- Main Event premium conectado a Fight Card real y único destacado por evento.
- upload/reencuadre persistente de cartel/banner.
- Organiza/Avala visibles en portada.
- fotos de participante externo y duelo visual en Social.
- Brand Heroes reparados para que el protagonista siempre sea visible.
- Supabase 178 aplicado; QA completo y build determinista PASS.

# 20.101 · Demo Event Showcase
- `Noche de Impacto · Barcelona · DEMO QA` instalado como evento público real en Supabase.
- 12 participantes, 6 combates y Main Event normal del dominio Events.
- Club Fénix Elite · DEMO + Federación Nova Combat · DEMO como organizaciones ficticias visibles.
- Banco multimedia completo incluido; auto-hidratación Owner de 10 imágenes hacia Storage privado.
- Seed/cleanup Owner-only e idempotentes; sin tablas/rutas demo paralelas.
- Web/PWA/Android 20101; regresión completa y build determinista PASS: 132 archivos idénticos.

# 20.100 · KOMBAX Brand Heroes
- Hero visual compartido para Social, Events y Showcase.
- Logo oficial KOMBAX como única marca gráfica.
- Fondos fotográficos locales optimizados y separados del copy HTML.
- Events adopta `FROM HYPE TO HISTORY` y `El espectáculo no empieza en el ring. Empieza aquí.`.
- Motion ambiental accesible y responsive móvil.
- Sin cambios Supabase ni contratos funcionales.

# 20.099 · Events Official Album + HD Media

- Álbum oficial Previo / Evento / Postevento.
- 15 fotos activas + 5 vídeos almacenados activos por evento.
- Vídeos de Eventos hasta 60 s, 1080p y 100 MB.
- Grid fotográfico seleccionable + lightbox + filtros.
- Multi-upload secuencial y contadores de cuota.
- Supabase 175/176: quota transaccional + idempotencia.
- Storage privado preservado.
- Límites históricos de vídeo de Comunidad/Social preservados.

# 20.098 · Events Large Format Experience

- Eventos pasan a gran formato de una columna, diferenciados de Showcase.
- Main Event teaser en portada y segundo nivel completo al entrar.
- Estados separados: evento, inscripciones y tickets.
- Venue, dirección, mapa, aforo, acceso, tickets/registro/streaming/web por enlaces HTTPS.
- Backend real: migraciones 173 y 174 aplicadas.
- Workspace isolation 20.097 preservado; Urban Warriors sigue sin entitlement hasta post-deploy.
- Web/PWA/Android 20098; JKS local incluido sin contraseñas.

# 20.096 · Events Premium Visual Identity

- Auditoría y rediseño visual de KOMBAX Eventos sobre 20.095.
- Iconografía propia, neon controlado, motion ambiental y acabado broadcast.
- Visual Engine/plantillas locales rediseñadas.
- Sin cambios backend.

# Changelog

## 2.0.0-rc.13 · build 20095 · Integration / Hardening Final Candidate

- Deep-links Android de Eventos conservan `event` y `fight` con validación estricta.
- Media firmada renueva firma ante fallo y descarga; degradación con reintento.
- Identidad web/PWA/Android local sincronizada a 20095.
- Netlify/CSP/Service Worker/Android WebView auditados.
- Regresión completa y build determinista PASS: 101 archivos web/dist/Android idénticos.
- Production health permanece 20094 hasta desplegar 20.095; no se realizó deploy ni publicación.
- Espectador sigue deshabilitado.

## 2.0.0-rc.13 · build 20063 · Social Messaging Final QA

- Chat Social: la X sale y conserva el hilo; desaparece `Cerrar chat`; `Eliminar conversación` queda como acción destructiva.
- Comentarios inline, sin segundo modal.
- UX pública `Mi red` / `Añadir a mi red`, manteniendo privacidad.
- Mensajes KOMBAX con badge independiente y acceso directo.
- Bandeja unificada con filtros Social/Showcase y contexto visual de producto.
- Showcase comercial preparado para hilo independiente por pareja+producto.
- Migración Supabase 107 preparada con compatibilidad v106/v104; no aplicada live al cierre del paquete.
- Build 20063: tests PASS, build PASS, 66 archivos web/dist/Android idénticos; Netlify no desplegado.

## 2.0.0-rc.13 · build 20058 · Navigation + Session UX · intervención 1

- Nueva jerarquía transversal de navegación: **Mi perfil → KOMBAX Social → KOMBAX Showcase → Mi Club**.
- `Mi Club` pasa a acordeón y conserva todos los accesos operativos permitidos por rol; la autorización de rutas no se relaja.
- Dirección/Coordinación separan `Mi perfil` personal de `Perfil del club`.
- En móvil, la navegación principal prioriza Mi perfil, Social, Showcase y Mi Club; Mi Club abre directamente el acordeón lateral.
- `Notificaciones del Club` deja de duplicarse en el menú lateral y permanece accesible desde la cabecera con identificación explícita de Club.
- Mejora del botón de menú móvil: mayor área táctil y señal visual estable.
- Un refresh token inválido o inexistente se convierte en expiración controlada de sesión y nunca expone el mensaje técnico de Supabase.
- Una pérdida puntual de conexión conserva la sesión local y permite reintentar al recuperar Internet, en vez de expulsar al usuario.
- Errores de sesión/red se traducen a mensajes humanos.
- Sin migración Supabase ni cambios de esquema en esta intervención.
- `npm test`: PASS. `npm run build`: PASS. Web/dist/Android: 65/65/65, hashes idénticos.
- Android preflight: 4/5; firma local sigue deliberadamente fuera del paquete.
- Esta es la **primera intervención de 20.058**, no el freeze final: la separación completa de Notificaciones KOMBAX / Club / Mensajes continúa en la siguiente intervención.

## 2.0.0-rc.13 · build 20030 · ámbitos de monitor y privacidad financiera

- Nuevo modelo muchos-a-muchos de ámbitos para varios monitores, alumnos y grupos dentro de un club.
- Separación backend entre acceso deportivo del monitor y ficha administrativa/familiar del socio.
- Documentos privados y recibos dejan de heredar visibilidad por ser monitor.
- `Mis alumnos` usa proyección mínima segura; contacto solo mediante permiso explícito.
- `Mi cartera` incorpora niveles none/status/portfolio/collect/receipts por ámbito.
- Asistencia, seguimiento, graduaciones, reservas y series quedan limitados por ámbito y flags de permiso.
- Nueva administración `Ámbitos y privacidad` para Gestor/Coordinación.
- Migración 057 con preflight, verify, test JWT A/B y rollback; no aplicar antes de 056.
- Regresión y build: PASS; 71 archivos sincronizados web/dist/Android; versionCode 20030.

## 2.0.0-rc.13 · build 20025 · Showcase y preparación de carga multiclub

- KOMBAX Showcase como escaparate informativo global con marcas, categorías, fichas, lanzamientos, precio orientativo opcional y enlaces HTTPS.
- Gestión autorizada de marcas y fichas mediante gestor explícito o entitlement; borrador, publicación y archivo conservan trazabilidad.
- No se implementan carrito, checkout, pagos, pedidos, stock, envíos, devoluciones ni comisiones.
- Seis fichas visuales sintéticas marcadas DEMO para presentación; no se escriben en Supabase ni contienen enlaces/ofertas reales.
- Catálogo paginado por cursor con límite de 24, búsqueda y filtrado por categoría.
- Migración local 042 con preflight, verificación, prueba transaccional y rollback conservador.
- Generadores deterministas y protegidos para escenarios QA de 10, 50 y 100 clubes.
- Harness K6 y runbook con percentiles, tasa de error, lecturas críticas y revisión de recursos/consultas.
- La preparación estática **no certifica** capacidad para 100 clubes; prueba real, Supabase, JKS, Android físico y Netlify continúan pendientes.

## 2.0.0-rc.13 · build 20024 · KOMBAX Social Alpha

- Nueva capa global KOMBAX Social, separada de la Comunidad del Club en datos, permisos, navegación y estética.
- Perfiles públicos proyectados de club, miembro autorizado y futuro perfil directo sin exponer expedientes ni datos administrativos.
- Feed profesional paginado por cursor en bloques máximos de 20, con publicaciones de texto, categorías y likes cuya identidad no se expone.
- Solicitudes estructuradas de contacto de 10–500 caracteres, con aceptación o rechazo y sin conversación, presencia ni mensajería encadenada.
- Bloqueo backend de contacto cuando cualquiera de los perfiles personales corresponde a un menor de 18 años.
- Denuncias, bloqueos, moderadores globales y auditoría de moderación; la suspensión social no altera la membresía del club.
- Normas KOMBAX Social 1.1 y activación opcional con consentimiento diferenciado.
- No se crean seguidores, amistades, chat, mensajes directos ni contadores de popularidad.
- Migración local 041 con preflight, verificación, prueba transaccional y rollback que conserva contenido.
- Supabase real, firma JKS, APK/AAB, instalación física y Netlify: **NO EJECUTADO** en esta fase.

## 2.0.0-rc.13 · build 20023 · puerta KOMBAX y base multiclub

- Nueva puerta pública KOMBAX con dos vías independientes: acceso mediante club y categorías de perfil directo.
- Directorio público limitado por nombre, ubicación o disciplina, compatible con enlace/QR y sin exponer datos administrativos.
- Urban Warriors permanece como club real; cinco clubes ficticios quedan identificados como DEMO y aislados en fixtures locales que no deben ejecutarse en producción.
- Categorías encajadas para competidor, marca, federación, espectador y profesional vinculado al deporte; altas, precios y cobros continúan expresamente cerrados.
- Contexto de acceso separado de identidad, suscripción y capacidades; cambio entre clubes limpia caché y estado del tenant anterior.
- Co-branding KOMBAX en acceso y registro, manteniendo `com.urbanwarriors.app` y la identidad instalada de Urban Warriors durante la transición.
- Migración local 040 con preflight, verificación, prueba transaccional y rollback conservador.
- KOMBAX Social y Showcase siguen desactivados; Supabase real, firma JKS, APK/AAB, instalación física y Netlify: **NO EJECUTADO** en esta fase.

## 2.0.0-rc.13 · build 20022 · estabilización y co-branding KOMBAX

- Corregida la lectura persistente de notificaciones individuales, por grupo e informativas, con estado optimista y reversión.
- Nombre completo renderizado con separación normalizada sin alterar el perfil.
- Nuevo archivo/papelera para nueve tipos de contenido, restauración durante 30 días y auditoría; pagos y recibos quedan excluidos.
- Recibos completos con logo del club, estado, detalle, impresión/guardar como PDF y compartición.
- Co-branding discreto KOMBAX manteniendo Urban Warriors como identidad principal e instalada.
- Cuatro temas cerrados, previsualización local, publicación versionada y restauración.
- Caché por club/usuario en lecturas seguras y métricas P50/P95/incidencias de más de cinco segundos.
- Migraciones locales 037–039 con preflight, verificación, prueba transaccional y rollback conservador.
- Supabase real, firma JKS, APK/AAB, instalación física y Netlify: **NO EJECUTADO** en esta fase.

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

## RC13 build 20028 · KOMBAX identity/public profiles/platform admin
Ver detalle en `CHANGELOG_RC13_BUILD_20028.md`. Build 20028 separa Miembro/Competidor, añade actuar como Club, Hub de Club, perfiles públicos, multimedia Social directa, Showcase accionable y Administración KOMBAX global mediante backend 051–056.

## RC13 build 20029 · 2026-08-17
- Compositor de texto visible y subida multimedia en KOMBAX Social.
- Feed con scroll progresivo automático y fallback manual.
- Showcase con subida desde dispositivo y Storage protegido en 054.
- Separación explícita Comunidad interna / KOMBAX Social público.
- Rojo sangre KOMBAX y microanimaciones premium.
- VersionCode 20029; suite/build completos PASS.

## RC13 build 20048 · PRE-FREEZE
- Perfil Miembro unificado con su identidad KOMBAX Social canónica.
- Perfil deportivo legacy retirado de la navegación activa y preservado solo como compatibilidad privada.
- Campos deportivos declarados integrados en Social; continuidad Competidor verificada.
- Directorio/Comunidad resuelven `social_id` canónico.
- Fondo Club negro con logo desenfocado; no usa portada como background global.
- Seguridad 20.046 revalidada; build/regresión final PASS.

## RC13 build 20049 · FINAL CANDIDATE
- Recuperación de contraseña por correo con OTP de 6 dígitos, verificación `recovery`, cambio de contraseña y cierre de sesión temporal.
- Botón de recuperación disponible en login Club y login KOMBAX; respuesta anti-enumeración.
- Plantilla KOMBAX `{{ .Token }}` incluida para Supabase Auth; su instalación alojada queda como único ajuste manual del flujo.
- Recibos convertidos a multi-club: snapshot del emisor, logo/nombre/contacto del Club y prefijo propio por Club.
- Eliminado fallback visual Urban Warriors para otros clubes; fallback neutro KOMBAX.
- Migración 096 aplicada/verificada en vivo; cuatro recibos históricos conservan sus números y reciben snapshot del emisor.
- Smoke financiero con rollback PASS; regresión/build PASS; web=dist=Android 63/63/63.

## 20.101 R52.2 — Social Android Poster Fix
- Corrige la resolución de portada/encuadre del vídeo en publicaciones de KOMBAX Social, especialmente en Android WebView.
- El feed usa el `media_id` resuelto de v238 y no deja que un `{}` vacío oculte la presentación real.
- Mantiene paridad Web / Android assets y prepara artefactos APK/AAB identificados como R52.2.

## 20.106 R56 · PROFILE PUBLIC UX QA FREEZE CANDIDATE
- Perfil público: álbum resumido a 5 elementos + álbum completo bajo demanda.
- Mi perfil: experiencia public-first; gestión agrupada en botón contextual del hero.
- Social 5 publicaciones y Showcase 4 productos preservados.
- Events/Social/Showcase/repositorios preservados respecto a R55.
- Build web/Android 20106; health sincronizado 20106.

## 20.107 R57 · SOCIAL INFO UX QA FREEZE CANDIDATE · 2026-09-06
- Identidad activa + normas/moderación completas salen del flujo principal de KOMBAX Social.
- Nuevo acceso compacto `Información de KOMBAX Social` en cabecera.
- Se conserva fundador, publicación, compositor, aviso corto, feed y lógica de moderación.
- Frontend-only; sin migración DB. Health actualizado a build 20107.
