# KOMBAX Guías - arquitectura territorial y búsqueda

**Revisión:** 21/09/2026  
**Estado:** contenido previo listo para futura implementación; no activa aún la capa funcional de KOMBAX Guías.

## Regla de composición

La experiencia futura no debe duplicar 15 guías por 19 territorios. KOMBAX compondrá:

**guía estatal/base + capa territorial diferencial + verificación municipal/federativa cuando proceda**.

Cada dato territorial se etiqueta como:

- `verified`: diferencia respaldada por una fuente oficial del territorio.
- `case`: no existe una respuesta universal que KOMBAX pueda publicar de forma segura; requiere comprobar municipio, recinto, modalidad/federación o datos del caso.
- `common`: marco estatal ya explicado por la guía base.

## Búsqueda prevista

El buscador permitirá seleccionar tema y comunidad/territorio. Opcionalmente podrá pedir municipio, modalidad y características del caso cuando estas variables cambien la respuesta.

Territorios: las 17 comunidades autónomas más Ceuta y Melilla.

Ejemplo de composición:

`Organizar un interclub` + `Andalucía` + `menores` -> marco estatal + protocolo andaluz de menores verificado + aviso de comprobación de recinto/municipio/federación + CTA de KOMBAX Consultoría si el usuario necesita revisar un evento concreto.

## Frontera con Consultoría

El CTA no debe presentarse como sustitución artificial de información disponible. Se activa cuando el usuario necesita aplicar la norma a datos concretos: municipio, recinto, aforo, modalidad/federación, menores, extranjeros, contratos, ticketing, actividad económica o documentación específica.

Texto previsto:

> **¿Necesitas aplicarlo a tu caso concreto?** KOMBAX Consultoría puede revisar territorio, modalidad, recinto, documentación y organismos competentes. La guía general no sustituye asesoramiento profesional específico.

## Datos preparados

- `artifacts/guides/territories/KOMBAX_TERRITORIAL_CATALOG_2026.json`
- `artifacts/guides/territories/KOMBAX_TERRITORIAL_DIFFERENTIAL_MATRIX_2026.json`
- `artifacts/catalogs/KOMBAX_GUIDES_TERRITORIAL_SEARCH_INDEX_2026.json`
- 19 PDFs territoriales individuales
- dossier maestro territorial
- fuentes Markdown en `docs/10_GUIDES_TERRITORIES/`

## Principio de seguridad editorial

No se publican como universales tasas, importes de seguro, permisos, plazos municipales, requisitos sanitarios, aforos, condiciones de recinto o reglas federativas si dependen del supuesto. La ausencia de un dato verificado no se rellena con una estimación.
