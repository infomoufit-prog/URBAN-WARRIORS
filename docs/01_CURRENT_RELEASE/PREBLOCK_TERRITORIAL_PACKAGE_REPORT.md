# KOMBAX · Package report · Preblock territorial guides

**Base:** R81 build 20134  
**Fecha:** 21/09/2026

Este paquete es acumulativo: conserva la base Fase 0, R81, R80, internacionalización y todo el bloque previo ya aprobado, y añade la expansión documental territorial de KOMBAX Guías.

## Contenido nuevo de este cierre

- 19 dossiers territoriales en Markdown.
- 19 PDFs territoriales.
- 1 PDF maestro territorial.
- catálogo territorial JSON.
- matriz diferencial JSON + Markdown.
- índice de búsqueda por territorio preparado para la futura UI.
- log de investigación y fuentes oficiales.
- arquitectura de composición temática + territorio + caso específico.
- gate automatizado 182/182 integrado en `npm test`.
- QA documental/PDF y logs de release.

## Garantías del paquete

- No activa todavía nuevas migraciones ni UI funcional de Guías.
- No contiene precios inventados de Consultoría.
- No contiene secretos Stripe, `.env` reales ni material privado de firma móvil.
- Android conserva la firma fuera del repositorio mediante `keystore.properties` local.
- Cada punto marcado como diferencial verificado tiene soporte en las fuentes oficiales registradas.
- Los puntos dependientes de municipio, recinto, modalidad, federación o caso individual se presentan como verificación específica, no como obligación universal.

## Gates finales

- Territorial: 182/182 PASS.
- Regresión acumulativa `npm test`: PASS.
- `npm run release:build`: PASS.
- `web = dist = Android`: 472 archivos.
- Android preflight: 4/5; única dependencia externa: firma local privada.
- iOS static parse/plist/entitlements: PASS.
- secret scan: 0.
- PDF preflight territorial: PASS.

Este ZIP pasa a ser la única base válida para el siguiente bloque del Plan Maestro una vez entregado y validado.
