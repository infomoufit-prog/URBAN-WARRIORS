# KOMBAX 20.101 R20 · QA VALIDATION
## Urban Warriors · Seminario Pro de Muay Thai · Adrián Serrano

Fecha de cierre técnico: 2026-08-29
Base: KOMBAX 20.101 R19 · SHOWCASE URBAN WARRIORS PRODUCTS

## Implementación
- Evento público real en dominio KOMBAX Events, slug estable `urban-warriors-seminario-pro-muay-thai-adrian-serrano-demo`.
- Organizador: Urban Warriors.
- Protagonista demo: Adrián Serrano, perfil ficticio de peleador profesional de Muay Thai.
- 4 assets principales: poster, banner y 2 imágenes de álbum postevento.
- 1 retrato local derivado para coherencia de tarjeta de participante.
- 2 publicaciones internas en Comunidad del club: anuncio + recap postevento.
- Soporte frontend para media seed local `demo-static:` en Comunidad sin alterar Storage normal.
- Eventos tipo seminario/clinic/masterclass/stage/campus sin combates no muestran Fight Card vacío.

## Backend real
Proyecto Supabase: `poggsobhtutbuagjiydc`.
Migración aplicada: `kombax_urban_warriors_muay_thai_seminar_20101_r20`.
Archivo reproducible: `supabase/migrations/186_kombax_urban_warriors_muay_thai_seminar_20101_r20.sql`.

Verificación posterior:
- event_count = 1
- protagonist_count = 1
- community_posts = 2
- cross_club = 0

Idempotencia: el bloque seed se ejecutó una segunda vez y mantuvo exactamente los mismos conteos.
El RPC público `app_kombax_eventos_publicos_v178` devuelve el seminario con tipo `seminario`, estado `finalizado`, organizador Urban Warriors y rutas de poster/banner correctas.

## Multiclub / permisos
- El seed resuelve Urban Warriors por slug/nombre estable.
- Requiere entitlement activo `events.public.organize`.
- El evento queda asociado exclusivamente al club Urban Warriors.
- Las dos publicaciones internas tienen `club_id` de Urban Warriors.
- Verificación cross-club del seed R20 = 0.
- La policy SELECT existente de `publicaciones_comunidad` exige `es_miembro_club(club_id)` para `authenticated`; no se creó ni debilitó ninguna policy RLS en R20.

## Tests
- `npm run test:20101:r20`: PASS.
- `npm test`: PASS, incluida toda la regresión histórica configurada en package.json y R19.
- `npm run build`: PASS; el build vuelve a ejecutar regresión y termina con `OK build 170 archivos · web = dist = Android`.

## Paridad
- web: 170 archivos
- dist: 170 archivos
- android/app/src/main/assets/www: 170 archivos
- Resultado del builder: igualdad web = dist = Android.

## Android
- applicationId: `com.urbanwarriors.app`
- versionCode: `20101` (NO incrementado en R20)
- versionName: `2.0.0-rc.13`
- JKS presente en `LOCAL_RELEASE_SIGNING/kombax-release.jks`.
- `android/keystore.properties`: NO presente; firma release física NO generada en esta revisión.

## Advisors Supabase
Security Advisor: ejecutado. El proyecto mantiene avisos históricos/globales ya existentes (incluidos avisos de RLS/políticas, EXECUTE de funciones security-definer y configuración de protección de contraseñas filtradas). R20 no crea tablas, funciones, RPC, GRANT o policies nuevas, por lo que no se atribuyen estos avisos a objetos nuevos de R20.

Performance Advisor: ejecutado. Mantiene avisos históricos/globales de foreign keys sin índice, índices sin uso y un índice duplicado en `informes_financieros`. R20 no añade tablas, foreign keys ni índices nuevos.

Estado correcto: ADVISORS EJECUTADOS, NO LIMPIOS GLOBALMENTE.

## Validación visual
Los assets fuente han sido generados e inspeccionados y están empaquetados. No se ha realizado en esta revisión una validación física completa de la UI R20 desplegada en navegador/PWA ni una instalación APK R20. Por tanto no se declara "responsive perfecto" ni "APK validada".

## Deploy
- Supabase backend: migración/datos R20 APLICADOS.
- Frontend Netlify/GitHub: NO desplegado desde esta revisión.
- Consecuencia: las rutas de assets locales R20 y el resolver `demo-static:` necesitan el frontend R20 para mostrarse visualmente en el deployment actual. El dato del evento ya existe en backend, pero no se declara publicación visual completa en producción hasta desplegar R20.

## Cierre
Cierre técnico local/backend: PASS con las limitaciones explícitas anteriores.
Cierre visual/despliegue frontend: PENDIENTE.
