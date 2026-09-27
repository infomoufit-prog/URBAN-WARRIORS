# KOMBAX · Expansión territorial de Guías · Informe final

**Base:** R81 build 20134  
**Fecha de cierre:** 21/09/2026  
**Alcance:** bloque previo de diseño y contenidos. No activa todavía las fases funcionales 1–5 del Plan Maestro.

## 1. Objetivo

Ampliar la colección KOMBAX Guías desde el marco estatal + primera capa Cataluña a una arquitectura consultable por territorio para las **17 comunidades autónomas, Ceuta y Melilla**. La ampliación no replica requisitos sin verificar: reutiliza la estructura documental, pero cada diferencial territorial publicado se respalda con fuentes oficiales y se separa de los puntos que requieren comprobación municipal, federativa, del recinto o del caso concreto.

## 2. Resultado entregado

Se incorporan **19 dossiers territoriales PDF**, un dossier maestro territorial, 19 fuentes Markdown estructuradas, un catálogo JSON, una matriz diferencial JSON/Markdown y un índice de búsqueda preparado para la futura interfaz de KOMBAX Guías.

La búsqueda futura queda preparada para componer:

1. guía temática estatal;
2. territorio seleccionado;
3. diferenciales territoriales verificados;
4. avisos de verificación específica;
5. municipio/modalidad opcionales cuando sean relevantes;
6. acceso contextual a KOMBAX Consultoría.

## 3. Territorios

Andalucía, Aragón, Principado de Asturias, Illes Balears, Canarias, Cantabria, Castilla-La Mancha, Castilla y León, Cataluña, Comunitat Valenciana, Extremadura, Galicia, Comunidad de Madrid, Región de Murcia, Comunidad Foral de Navarra, País Vasco/Euskadi, La Rioja, Ceuta y Melilla.

## 4. Política de no invención

La estructura usa tres estados conceptuales:

- **Diferencial verificado:** información territorial apoyada por una fuente oficial identificada.
- **Marco común:** materia regulada principalmente por el marco estatal ya documentado en la guía temática.
- **Verificación específica:** punto que no puede resolverse de forma universal porque depende de municipio, instalación, aforo, modalidad, federación, participantes o circunstancias concretas.

No se han inventado tasas, precios, cuantías de seguros, plazos municipales, permisos de instalaciones, requisitos sanitarios ni condiciones federativas no respaldadas por una fuente oficial aplicable.

## 5. KOMBAX Consultoría

La consultoría aparece como **frontera de precisión**, no como sustitución artificial de información disponible. Cuando una guía general no permite determinar el requisito exacto, el CTA explica qué elementos deben revisarse: territorio, municipio, recinto, modalidad/federación, participantes y documentación.

Ejemplo de clasificación:

> Una velada con público, menores y deportistas extranjeros puede requerir revisar simultáneamente normativa deportiva, protección de menores, recinto/actividad, federación/modalidad y situación individual de participantes. La guía ofrece el marco verificable; KOMBAX Consultoría puede revisar el expediente concreto y los organismos competentes.

## 6. Artefactos principales

- `docs/10_GUIDES_TERRITORIES/` — 19 fuentes territoriales.
- `docs/10_GUIDES_TERRITORIES/TERRITORIAL_SOURCES_MATRIX.md` — matriz de fuentes.
- `docs/10_GUIDES_TERRITORIES/TERRITORIAL_DIFFERENTIAL_MATRIX.md` — matriz legible de diferenciales.
- `artifacts/guides/territories/KOMBAX_GUIAS_TERRITORIOS_ESPANA_2026.pdf` — dossier maestro.
- `artifacts/guides/territories/KOMBAX_TERRITORIAL_CATALOG_2026.json` — catálogo territorial.
- `artifacts/guides/territories/KOMBAX_TERRITORIAL_DIFFERENTIAL_MATRIX_2026.json` — datos diferenciales.
- `artifacts/catalogs/KOMBAX_GUIDES_TERRITORIAL_SEARCH_INDEX_2026.json` — índice para futura búsqueda.
- `docs/01_CURRENT_RELEASE/PREBLOCK_TERRITORIAL_SEARCH_ARCHITECTURE.md` — contrato de integración.
- `docs/01_CURRENT_RELEASE/PREBLOCK_TERRITORIAL_RESEARCH_LOG_2026-09-21.md` — trazabilidad de investigación.

## 7. QA

- Gate territorial: **182/182 PASS**.
- `npm test`: **PASS** acumulativo.
- `npm run release:build`: **PASS**.
- Legal gate: **PASS**.
- Build: **472 archivos; web = dist = Android**.
- PDFs territoriales: **20/20** (19 individuales + maestro) sin errores de preflight.
- Dossier maestro territorial: **21 páginas A4**, renderizado e inspeccionado visualmente.
- Android preflight: **4/5**, pendiente únicamente `android/keystore.properties` privado local.
- iOS `swiftc -parse`: **PASS**; plist/entitlements: **PASS**.
- Escaneo de secretos: **0 archivos privados / 0 tokens privados detectados**.

## 8. Estado de implementación

Este bloque es **contenido y arquitectura de datos previa a UI**. No se ha creado todavía la nueva navegación funcional de KOMBAX Guías ni nuevas migraciones Supabase para este contenido. Esto es deliberado: las fases funcionales posteriores podrán consumir una base documental ya verificada y estructurada sin diseñar la normativa al mismo tiempo que el software.

## 9. Siguiente paso del Plan Maestro

Con este ZIP congelado se puede iniciar, cuando el usuario lo autorice, el **Bloque 1 / fases 1–5**: Showcase Commerce, Stripe Checkout, KOMBAX Finance multientidad e integración común de métodos de pago.
