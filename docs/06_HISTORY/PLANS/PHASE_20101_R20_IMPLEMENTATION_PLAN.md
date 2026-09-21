# KOMBAX 20.101 R20 · Plan de fase

## Objetivo
Integrar un seminario profesional ficticio de Muay Thai organizado por Urban Warriors, con Adrián Serrano como protagonista, en el dominio real de KOMBAX Events y en la Comunidad interna del club.

## Alcance
- Evento público tipo `seminario`, finalizado, de Urban Warriors.
- Cartel, banner y dos imágenes postevento; retrato derivado del banner para la tarjeta del protagonista.
- Dos publicaciones internas idempotentes: anuncio y recap.
- Seed real multiclub aislado por `club_id`.
- Ajuste UX mínimo: un seminario sin combates no muestra una Fight Card vacía.
- Resolver `demo-static:` solo para assets empaquetados de seed; los uploads normales siguen usando Storage privado.

## Fuera de alcance
Finanzas, Auth, Social público, Showcase, despliegue Netlify, versionCode Android y Google Play.

## Archivos/módulos afectados
`web/js/modules/kombax-events.js`, `web/js/core/repositories.js`, assets demo del seminario, migración 186, verificación y test R20.

## Backend
`kombax_eventos_publicos`, `kombax_evento_entidades`, `kombax_evento_participantes_publicos`, `publicaciones_comunidad`. No se crea tabla/RPC/Edge Function nueva.

## Riesgos
Duplicados seed, publicación en club incorrecto, cartel/álbum roto antes de desplegar los assets web, regresión de resolución de media comunitaria.

## Preservación seed
Slug natural único para el evento; media_path natural para las dos publicaciones; la migración aborta si detecta multiplicidad previa. No usa TRUNCATE ni limpieza general.

## QA
Test dedicado R20, suite completa `npm test`, build determinista web=dist=Android, queries backend e idempotencia mediante reaplicación equivalente, comprobación de RLS/entitlement y advisors.

## Cierre
Evento=1, Adrián=1, publicaciones internas=2, cross-club=0, tests/build PASS; ZIP R20 + SHA-256. Validación visual física queda separada si no se despliega/instala.
