# KOMBAX · Bloque previo territorial profesional detallado
## Informe final · 21/09/2026

## Estado

**CERRADO para contenidos y documentación.** No se han iniciado las fases funcionales 1-5 del Plan Maestro.

Base técnica preservada: **R81 build 20134**.

La finalidad de esta ampliación ha sido sustituir el dossier territorial resumido por una capa profesional de trabajo que ayude a un club, organizador, federación o profesional a **planificar qué debe comprobar y preparar**, sin convertir KOMBAX Guías en una falsa autorización automática ni inventar requisitos que dependan del caso.

## Resultado editorial

Se han generado **19 dossiers territoriales profesionales**, uno por cada comunidad autónoma y por Ceuta/Melilla, más un dossier maestro de España.

- 19 PDFs territoriales detallados.
- 156 páginas acumuladas en los PDFs territoriales individuales.
- 1 dossier maestro profesional de **141 páginas A4**.
- 19 fuentes Markdown estructuradas.
- índice JSON para futura búsqueda/ingestión.
- metodología y límites de publicación.
- Prompt Maestro de Continuación para las Fases 1-5.

Cada territorio contiene:

1. alcance y forma correcta de utilizar el dossier;
2. mapa de decisión previo;
3. diferenciales autonómicos verificados;
4. ruta práctica para crear/operar entidad deportiva;
5. ruta práctica para evento/velada/interclub;
6. aplicación de las 15 materias KOMBAX;
7. ejemplo operativo;
8. checklist antes de publicar/ejecutar;
9. disparadores de KOMBAX Consultoría;
10. límites de KOMBAX Consultoría;
11. fuentes oficiales territoriales;
12. fuentes estatales comunes;
13. límite de actualización y obligación de comprobar vigencia.

## Principio de no invención

La ampliación no utiliza una comunidad como plantilla normativa de otra. La **estructura editorial sí se replica**, pero los diferenciales territoriales marcados como verificados se apoyan en fuentes oficiales identificadas en cada dossier.

Cuando no existe una regla autonómica única o el resultado depende de municipio, instalación, federación, modalidad, aforo, participantes, extranjería, seguros o circunstancias concretas, el documento lo identifica como **verificación específica**.

No se han inventado:

- permisos municipales;
- tasas o importes no verificados;
- capitales/coberturas de póliza universales;
- plazos locales no publicados;
- reglas federativas de una modalidad concreta;
- requisitos sanitarios únicos para toda España;
- situación jurídica individual de deportistas extranjeros;
- precios de KOMBAX Consultoría.

## KOMBAX Consultoría

La derivación a Consultoría no sustituye información pública. Se activa cuando la persona necesita transformar el marco general en un expediente concreto, por ejemplo:

- clasificar correctamente un evento real;
- identificar administraciones y organismos implicados;
- ordenar documentación disponible/faltante;
- contrastar ayuntamiento + recinto + federación + seguros;
- determinar qué asunto debe validar un profesional habilitado o la autoridad competente.

KOMBAX Consultoría no debe prometer una autorización, licencia, inscripción ni un dictamen reservado a profesiones reguladas.

## Ejemplos de profundidad territorial incorporada

La colección documenta diferencias reales, entre otras:

- Madrid: distinción y documentación diferente para clubes elementales y básicos y plazo registral publicado.
- Asturias: figuras y trámite propios, incluyendo requisitos publicados para club básico.
- Illes Balears: regímenes de constitución diferenciados publicados por la administración autonómica.
- Castilla-La Mancha: requisitos constitutivos y registrales propios.
- Galicia: el procedimiento registral incorpora documentación de protección de menores.
- Comunitat Valenciana: reserva de nombre y documentación/adscripción publicada según tipo de entidad.
- Navarra: regulación específica del ejercicio de profesiones del deporte y registro/declaración correspondiente.
- Canarias: procedimientos registrales y tramitación electrónica autonómica.

Estos ejemplos no se extrapolan automáticamente a otra comunidad.

## Entregables clave incluidos en el ZIP

- `docs/11_GUIDES_TERRITORIES_DETAILED/`
- `artifacts/guides/territories-detailed/`
- `docs/11_GUIDES_TERRITORIES_DETAILED/territories_detailed_index.json`
- `docs/11_GUIDES_TERRITORIES_DETAILED/METODOLOGIA_Y_LIMITES_EDICION_DETALLADA.md`
- `docs/01_CURRENT_RELEASE/PROMPT_MAESTRO_CONTINUACION_KOMBAX_BLOQUE1_FASES_1_5.md`
- `artifacts/guides/PROMPT_MAESTRO_CONTINUACION_KOMBAX_BLOQUE1_FASES_1_5.pdf`

## Runtime

No se ha activado todavía en el frontend la UI definitiva de KOMBAX Guías ni la búsqueda territorial. Esa implementación corresponde al bloque funcional posterior definido en el Plan Maestro. Por ello se mantiene **build 20134**: el trabajo de esta entrega es documental/editorial y de QA, no una nueva release runtime.
