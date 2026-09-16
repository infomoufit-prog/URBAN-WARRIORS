> CURRENT CUMULATIVE SOURCE: KOMBAX R79 / build 20130 (i18n completion phases 6–10).

# KOMBAX · R77 build 20128 · Premium Analytics & Reports

**Fuente de verdad acumulativa actual para la siguiente fase.** R77 conserva íntegramente R76/R75 y añade Analytics/Reports premium para Showcase y Events, producto 1:1 responsive, resultados deportivos e informes PDF privados. Supabase R77 está aplicado; GitHub/Netlify/Play no se han desplegado. Estado: **PILOT FREEZE CANDIDATE**.

Consulta `KOMBAX_20128_R77_FINAL_REPORT.md`, `R77_SHOWCASE_EVENTS_ANALYTICS_REPORTS_AUDIT.md`, `KOMBAX_20128_R77_QA_SUMMARY.json` y `QA_HANDOFF_20128_R77.md`.

---

# KOMBAX · RC13 build 20.101 R3 · Event Visual Editor Hardening

Fuente de verdad actual para QA. Conserva 20.101 y cierra los defectos visuales detectados en la validación local: Main Event conectado a Fight Card real, organización/aval visibles arriba, upload y reencuadre persistente de cartel/banner, fotos de participantes externos, referencias Social con peleadores y Brand Heroes con protagonistas visibles. Supabase 178 está aplicado. El evento público de referencia se presenta como `Noche de Impacto · Barcelona`. JKS real incluido en `LOCAL_RELEASE_SIGNING/`, sin contraseñas.

Consulta `BUILD_20101_EVENT_VISUAL_EDITOR_HARDENING_VALIDATION.md`, `SUPABASE_EVENT_VISUAL_AUDIT_20101_R3.md`, `LOCAL_QA_CHECKLIST_20101_R3.md` y `PROMPT_MAESTRO_CONTINUIDAD_20101.md`.

---

# KOMBAX · RC13 build 20.101 · Demo Event Showcase

Fuente de verdad actual para QA. Conserva íntegramente 20.100 y añade `Noche de Impacto · Barcelona · DEMO QA` como evento público real del dominio KOMBAX Events, con 12 participantes, 6 Fight Cards y banco multimedia completo. El evento ya existe en Supabase por su slug normal; el álbum de 10 imágenes se auto-hidrata al bucket privado al entrar con sesión Owner en 20.101. JKS real incluido en `LOCAL_RELEASE_SIGNING/`, sin contraseñas.

Consulta `BUILD_20101_DEMO_EVENT_SHOWCASE_VALIDATION.md`, `SUPABASE_DEMO_EVENT_AUDIT_20101.md`, `DEMO_EVENT_QA_GUIDE_20101.md` y `PROMPT_MAESTRO_CONTINUIDAD_20101.md`.

---

# KOMBAX · RC13 build 20.100 · Brand Heroes

Fuente de verdad actual para QA. Conserva íntegramente 20.099 y establece la identidad Hero definitiva de KOMBAX Social, KOMBAX Events y KOMBAX Showcase usando exclusivamente el logo oficial existente. Events mantiene `FROM HYPE TO HISTORY` y `El espectáculo no empieza en el ring. Empieza aquí.`. No hay migraciones Supabase nuevas. JKS real incluido en `LOCAL_RELEASE_SIGNING/`, sin contraseñas.

Consulta `BUILD_20100_KOMBAX_BRAND_HEROES_VALIDATION.md`, `BRAND_HEROES_VISUAL_SYSTEM_20100.md` y `PROMPT_MAESTRO_CONTINUIDAD_20100.md`.

---

# KOMBAX · RC13 build 20.099 · Events Official Album + HD Media

Fuente de verdad actual para QA de KOMBAX Eventos. Mantiene Large Format 20.098 y añade el álbum oficial del evento: 15 fotos, 5 vídeos HD de hasta 60 s, fases previo/evento/postevento, cuadrícula seleccionable y lightbox. Supabase 175/176 aplicado; Storage de Eventos sigue privado. JKS real incluido en `LOCAL_RELEASE_SIGNING/`, sin contraseñas.

Consulta `BUILD_20099_EVENTS_OFFICIAL_ALBUM_MEDIA_VALIDATION.md`, `SUPABASE_EVENTS_ALBUM_AUDIT_20099.md` y `PROMPT_MAESTRO_CONTINUIDAD_20099.md`.

---

# KOMBAX · RC13 build 20.098 · Events Large Format Experience

Esta carpeta es la fuente de verdad posterior a 20.097 para la experiencia pública de **KOMBAX Eventos**. Mantiene el aislamiento de workspace y la identidad visual premium, y añade gran formato, estados independientes y segundo nivel completo del evento.

## Identidad 20.098
- web/PWA: `20098`;
- Android `versionCode`: `20098`;
- backend Eventos real: migraciones hasta `174`;
- `health` productivo permanece 20094 hasta deploy; source local 20098;
- JKS de release incluido en `LOCAL_RELEASE_SIGNING/`, sin contraseñas.

## Experiencia
- feed de eventos grandes y diferenciado de Showcase;
- Main Event en la portada;
- evento, inscripciones y tickets con estados independientes;
- venue/dirección/mapa/acceso/aforo;
- links externos de entradas, inscripción y streaming;
- detalle completo: Información · Main Event · Fight Card · Peleadores · Organización · Highlights.

Consulta `BUILD_20098_EVENTS_LARGE_FORMAT_VALIDATION.md` y `SUPABASE_EVENTS_LARGE_FORMAT_AUDIT_20098.md`.

---

# KOMBAX · RC13 build 20.096 · Events Premium Visual Identity

Esta carpeta es la fuente de verdad posterior a 20.095 para la mejora visual de **KOMBAX Eventos**. Mantiene intacta la arquitectura funcional y de seguridad y añade una nueva capa estética premium/broadcast.

## Identidad
- build web/PWA: `20096`;
- Android `versionCode`: `20096`;
- fuente frontend: `web/`;
- `dist/` y Android generados desde `web/`;
- 102 archivos frontend idénticos entre destinos.

## Qué cambia
- iconografía propia de Eventos;
- rojo KOMBAX + cyan/violet neon controlado;
- fondo animado local;
- hero, cards, tabs, detalle y landing pública refinados;
- Fight Cards con acabado broadcast;
- sponsors y highlights premium;
- plantillas Visual Engine rediseñadas sin API;
- motion accesible y Android-first.

## Qué no cambia
- backend/RLS/RPC;
- separación Mi Club > Eventos;
- modelo de participantes/combates/resultados;
- Storage privado;
- Espectador permanece cerrado.

Consulta `VISUAL_AUDIT_20096.md` y `BUILD_20096_EVENTS_PREMIUM_VISUAL_VALIDATION.md`.

---

# KOMBAX · RC13 build 20.095 · Integration / Hardening Final Candidate

Esta carpeta es la **fuente de verdad** para la siguiente validación real de KOMBAX en Netlify y Android. Parte de 20.094 y no introduce una nueva gran funcionalidad: cierra integración, deep-links, degradación de media y consistencia de release.

## Identidad

- versión: `2.0.0-rc.13`;
- build web/PWA: `20095`;
- Android `applicationId`: `com.urbanwarriors.app`;
- Android `versionCode`: `20095`;
- fuente canónica frontend: `web/`;
- `dist/` y `android/app/src/main/assets/www/`: generados y verificados desde `web/`;
- 101 archivos frontend idénticos en los tres destinos.

## Qué cierra 20.095

- Deep-links Android de KOMBAX Eventos conservan `event` y `fight` con validación estricta.
- La landing pública de evento continúa abriéndose antes del login.
- URLs firmadas del álbum/highlights se renuevan ante error y al descargar; Storage sigue privado.
- Netlify mantiene fallback SPA y CSP compatible con Supabase/media HTTPS.
- WebView Android mantiene `usesCleartextTraffic=false`, mixed-content bloqueado y acceso a archivos deshabilitado.
- Service Worker no cachea URLs firmadas externas.
- Espectador sigue deshabilitado hasta su gate específico de edad/privacidad.

## Estado certificado

- `npm test`: PASS.
- `npm run build`: PASS.
- `npm run release:legal-gate`: PASS.
- `web = dist = Android`: 101/101/101, hashes idénticos.
- Android preflight: 4/5 en este entorno; únicamente falta la firma local, deliberadamente excluida del paquete.
- Supabase productivo conserva Eventos 20.094 aplicado; `event-media-url` v1 ACTIVE; bucket de Eventos privado.
- `health` productivo permanece correctamente en build 20094 hasta que 20.095 sea desplegada. El archivo local de `health` ya está preparado para 20095.

## No incluido / no ejecutado

- No se ha desplegado Netlify.
- No se ha publicado Google Play.
- No se incluye JKS, contraseña ni `keystore.properties`.
- No se genera una clave nueva.
- No se activa Espectador.
- App Links Android verificados (`autoVerify`) siguen pendientes de confirmar la huella de **Play App Signing** y publicar Digital Asset Links; no se debe asumir que la huella histórica de la clave de subida sea la misma.

## Siguiente paso

Usar `VALIDACION_NETLIFY_ANDROID_20095.md`. Primero validar el mismo ZIP/carpeta en el PC autorizado, después desplegar Netlify, verificar producción, actualizar `health` a 20095 y finalmente generar APK/AAB con el keystore existente.

## KOMBAX 20.097 · Events Workspace Isolation
See `BUILD_20097_EVENTS_WORKSPACE_ISOLATION_VALIDATION.md`, `SUPABASE_EVENTS_WORKSPACE_AUDIT_20097.md` and `PROMPT_MAESTRO_CONTINUIDAD_20097.md`.
