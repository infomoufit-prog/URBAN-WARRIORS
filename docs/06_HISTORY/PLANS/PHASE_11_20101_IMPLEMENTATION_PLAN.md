# Phase 11 · build 20.101 · Demo Event Showcase · Implementation Plan

## Alcance
Convertir el banco de imágenes ficticias en un evento de referencia accesible por el flujo real de KOMBAX Events. Debe existir en Supabase, aparecer por lectores públicos normales y usar las tablas/RPC/storage/album/Fight Cards existentes.

## No alcance
- no crear un modo demo paralelo;
- no procesar pagos reales;
- no activar Spectator;
- no mezclar Mi Club > Eventos;
- no usar datos privados reales de alumnos;
- no desplegar Netlify ni publicar Google Play.

## Riesgos
1. contaminar producción con entidades demo indistinguibles: mitigar con sufijo `DEMO QA` y cleanup Owner-only;
2. relajar ACL para facilitar el seed: prohibido; seed/cleanup authenticated + Owner check;
3. saltarse Storage privado: prohibido; media debe usar bucket real y signed URLs;
4. duplicar evento al reintentar: seed e hidratación deben ser idempotentes;
5. introducir fetch directo en UI: transporte solo por backend/repositorio;
6. contradicciones en cartelería/fechas: unificar a 18 OCT 2026;
7. mezclar Club/Federación de workspace: conservar aislamiento 20.097.

## Backend
- migración aditiva 177;
- RPC Owner seed/cleanup;
- evento, participantes, fights y organizaciones en tablas normales;
- ACL verificada en Supabase real;
- sin nuevas tablas demo.

## Frontend/assets
- banco local `assets/demo-events/noche-impacto-barcelona/`;
- panel QA Owner;
- auto-hidratación del álbum si el evento ya existe y está vacío;
- después de instalar, `openEvent(eventId)` normal.

## QA
- test específico 20.101;
- regresión histórica completa;
- build determinista;
- paridad web/dist/Android;
- legal gate;
- Android preflight;
- consulta live del slug, participantes y fights;
- empaquetado/hashes.

## Criterios de cierre
- evento real presente por slug;
- 12 participantes y 6 fights;
- Seed/cleanup no ejecutables por anon;
- álbum preparado para Storage privado normal;
- todos los tests PASS;
- ZIP autocontenido con documentación y JKS solicitado, sin credenciales.
