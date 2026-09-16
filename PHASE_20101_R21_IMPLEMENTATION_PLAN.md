# KOMBAX 20.101 R21 · GLOBAL MEDIA FRAMING + EVENTS TYPES + SOCIAL/SHOWCASE RESPONSIVE

## 1. Objetivo
Consolidar un sistema multimedia transversal y reutilizable que evite recortes incorrectos y permita presentar imágenes con encuadre adecuado según contexto, sin romper la arquitectura existente. Adaptar además KOMBAX Events para que los eventos formativos (seminario, masterclass y formación/circuito) tengan una experiencia distinta de los eventos competitivos, y corregir los overflows/responsive observados en móvil.

## 2. Alcance exacto
- KOMBAX Events: carteles, banners, Fight Cards, fotos de participantes, álbumes, miniaturas, navegación responsive y render por familia de evento.
- Event Creator: reutilizar/expandir ajustes de foco existentes y adaptar campos/preview según familia competitiva o formativa cuando la arquitectura lo permita sin duplicar el sistema.
- KOMBAX Showcase/materiales: cards y fichas de producto con prioridad a visibilidad completa del objeto y encuadre configurable.
- KOMBAX Social / Combat Social: feed, publicaciones, media simple/múltiple, vista de post, miniaturas y comportamiento visual similar a una red social moderna.
- Mi perfil / Mi contenido: avatar/banner/media/publicaciones y grids donde aplique.
- Mi Club / Comunidad: publicaciones internas, imágenes, miniaturas y visualización multimedia.
- Responsive: móvil portrait/landscape, tablet portrait/landscape y PWA/PC en los módulos anteriores.
- QA técnico y visual con fixtures/local assets existentes.

## 3. Fuera de alcance
- Finanzas, pagos, recibos y automatizaciones financieras.
- Auth, recuperación de contraseña y onboarding salvo regresión indirecta.
- Nuevos sistemas de mensajería o contactos.
- Rediseño total de branding o navegación global.
- Deploy Netlify o push GitHub sin autorización explícita.
- Publicación Google Play / incremento de versionCode sin necesidad validada.

## 4. Archivos/módulos probables
Se determinarán tras auditoría, priorizando helpers/componentes existentes. Previsibles: CSS/JS de Events, Social, Showcase, Perfil, Comunidad, upload/media helpers, builder/parity scripts y tests específicos R21.

## 5. Tablas / RPC / Storage / Edge Functions
Primero se auditará si los campos existentes de foco/posición/metadata permiten cubrir la necesidad. Se evitará una migración si puede resolverse de forma compatible en frontend utilizando metadata ya disponible. Si son necesarios campos persistentes nuevos, se hará migración aditiva, idempotente y multiclub, aplicada al Supabase principal y verificada con RLS/GRANT/RPC/advisors. No se creará un sistema paralelo de media.

## 6. Riesgos
- Cambiar `object-fit` globalmente y degradar otros contextos.
- Introducir distorsión/espacios vacíos en productos o retratos.
- Romper layouts de Fight Card o grid Social.
- Hacer más pesado el feed por procesamiento innecesario.
- Romper compatibilidad con media histórica sin metadata de encuadre.

## 7. Riesgos de regresión
- Events existentes R18/R20 y Fight Cards.
- Los 3 productos Showcase R19.
- Feed Social, comentarios y perfil público.
- Comunidad interna y sus permisos.
- Paridad `web = dist = android/app/src/main/assets/www`.

## 8. Riesgos multiclub
Los metadatos de media y cualquier write deben respetar propietario, `club_id`, workspace, actor y RLS existentes. No se permitirán actualizaciones de media de otra entidad/club por reutilización de ids o rutas.

## 9. Riesgos de datos
- No borrar ni reemplazar originales.
- No reescribir seed histórico salvo ajuste explícito e idempotente.
- Preservar rutas Storage/URLs y natural keys.
- Backward compatibility: media sin metadata deberá renderizar con defaults seguros.

## 10. Estrategia de migración
Preferencia: solución sin migración mediante normalizador común de presentación y campos existentes. Si falta persistencia real para foco/zoom/fit, migración aditiva con defaults nulos/auto, sin UPDATE masivo destructivo. Aplicación real a Supabase solo tras inspección y test local.

## 11. Estrategia de preservación de seed
R20 se mantiene intacta. R21 parte de copia física de R20. Los eventos/productos demo existentes no se eliminan. Si se añaden ajustes seed, usar slug/natural key y ejecución doble con conteos exactos.

## 12. Estrategia QA
- Auditoría estática de media (`object-fit`, `object-position`, aspect ratios, overflow, grids).
- Test dedicado R21 para normalización y reglas por contexto.
- `npm test` completo.
- `npm run build` y paridad web/dist/Android.
- Pruebas de layout con viewport móvil/tablet/desktop usando el runtime disponible.
- Verificación de Events competitivo vs formativo.
- Verificación de Showcase/productos, Social, Perfil y Comunidad.
- Si backend cambia: SQL aplicado, RLS/RPC/GRANT/advisors y E2E.

## 13. Criterios de cierre
R21 solo se cierra cuando:
1. no existe overflow horizontal en los flujos auditados;
2. Fight Cards permiten/renderizan foco y proporción sin recorte absurdo;
3. productos Showcase muestran el objeto de forma comercialmente útil;
4. Social/Perfil/Comunidad usan reglas multimedia coherentes y no destructivas;
5. álbumes mantienen miniatura correcta y original completo;
6. eventos formativos no presentan Fight Card/Main Event impropios y muestran información formativa;
7. regresión completa PASS;
8. build PASS y paridad web=dist=Android;
9. si hay backend, migración real + verificación y advisors ejecutados;
10. ZIP autocontenido R21 + SHA-256 + changelog + QA + continuidad.

## Closure evidence (2026-08-29)
- Media presentation upload points audited end-to-end.
- Completion migration 188 added for previously uncovered avatar/sports/club/Showcase-gallery presentation paths.
- Dedicated R21 test: 30/30 PASS.
- Full regression: PASS.
- Build/parity: PASS, 171 files each in web/dist/Android.
- Supabase main backend migrations 187+188 applied and verified.
- Seed preservation verified: R19 3 products; R20 1 seminar + 2 Community posts; cross-club 0.
- Security/Performance advisors executed; inherited warnings remain and are documented.
- Physical visual acceptance / Signed APK remains user-side PENDING.
