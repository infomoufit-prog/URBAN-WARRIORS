# KOMBAX · Bloque previo de diseño y contenidos · Informe final
**Base de ejecución:** R81 build 20134 Phase 0 auditada  
**Fecha:** 21/09/2026  
**Estado:** CERRADO · listo para servir de base acumulativa del siguiente bloque

## 1. Alcance ejecutado
Este bloque se ha limitado deliberadamente a diseño y contenidos. No se han activado funciones productivas nuevas ni se han iniciado las fases funcionales 1-5 del Plan Maestro.

Se han completado:

1. Revisión del Plan Maestro pendiente y de la auditoría Phase 0.
2. Auditoría del lenguaje visual existente (Social, Showcase, Events y shell KOMBAX).
3. Sustitución de la primera propuesta visual rechazada por la familia aprobada por el usuario.
4. Assets finales para KOMBAX Guías, KOMBAX Consultoría y KOMBAX Formación.
5. Investigación oficial para la colección inicial de KOMBAX Guías.
6. 15 guías fuente estructuradas en Markdown/JSON.
7. 15 PDFs profesionales descargables.
8. Dossier maestro de 33 páginas.
9. Matriz y log de fuentes/limitaciones.
10. Arquitectura de contenido de KOMBAX Consultoría y catálogo seed sin importes.
11. Arquitectura privada de KOMBAX Formación sin inventar oferta/acreditaciones del socio piloto.
12. Regresión acumulativa de KOMBAX y validaciones Android/iOS/documentales.

## 2. Assets aprobados
Directorio: `artifacts/assets/`

### KOMBAX Guías
- `kombax-guides-hero.webp`
- `kombax-guides-tablet.webp`
- `kombax-guides-card.webp`

### KOMBAX Consultoría
- `kombax-consulting-hero.webp`
- `kombax-consulting-tablet.webp`
- `kombax-consulting-card.webp`

### KOMBAX Formación
- `kombax-training-hero.webp`
- `kombax-training-tablet.webp`
- `kombax-training-card.webp`

Los PNG originales aprobados se conservan bajo `artifacts/assets/sources-approved/`.

La dirección final evita personas de stock como concepto central y utiliza recinto/gimnasio, material de deportes de contacto, interfaces, documentación, estrategia y certificación dentro del lenguaje dark-premium de KOMBAX.

## 3. Colección KOMBAX Guías
Directorio canónico preparatorio: `docs/09_GUIDES_SOURCE/`.

1. Crear un club o asociación deportiva.
2. Organizar un evento de deportes de contacto.
3. Organizar un interclub.
4. Licencias deportivas: alta, renovación y gestión.
5. Seguros y coberturas.
6. Menores en actividad y competición deportiva.
7. Instalaciones, recintos y autorizaciones.
8. Protección de datos, imagen y comunicaciones.
9. Ticketing, venta de entradas y control de acceso.
10. Federaciones y relaciones federativas.
11. Deportistas extranjeros y participación internacional.
12. Patrocinio, marcas y colaboraciones.
13. Organización de combates y participantes.
14. Documentación y checklist del organizador.
15. Obligaciones posteriores al evento.

Todos los dossiers contienen alcance, revisión, marco verificado, ruta práctica, checklist, ejemplo, derivación a KOMBAX Consultoría, fuentes oficiales y límites.

## 4. Principio de no invención
No se fijan como universales datos que dependen del supuesto: tasas, precios de licencias/seguros, honorarios, plazos municipales, número de personal técnico/sanitario/seguridad, requisitos de federación o modalidad, tratamiento fiscal individual, visado/trabajo de un participante o resultado de un expediente.

La primera capa autonómica desarrollada es Cataluña. Otras comunidades se añadirán únicamente tras investigación equivalente.

## 5. KOMBAX Consultoría
Se prepara una capa separada de Guías para casos que necesitan examen concreto. El catálogo seed se encuentra en `artifacts/catalogs/KOMBAX_CONSULTORIA_SERVICES_SEED_2026.json`.

No existen precios aprobados. Todos los `price_minor` permanecen `null`; la futura UI admite `fixed`, `from` o `quote` cuando KOMBAX defina el catálogo comercial.

La consultoría no deberá aparentar emitir dictámenes reservados a profesionales habilitados: clasifica, revisa operativa/documentos y deriva cuando corresponda.

## 6. KOMBAX Formación
Se mantiene como producto distinto de Guías y Consultoría y oculto por defecto. El documento `PREBLOCK_TRAINING_PRIVATE_LAYER_ARCHITECTURE.md` prepara cursos, módulos, prácticas, recursos/ISO aportados por la entidad, licencias formativas, evaluación, seguimiento y formación práctica en KOMBAX, sin inventar acreditaciones ni oferta del socio piloto.

## 7. Estado técnico
- Runtime: R81 build 20134, sin cambio de versionCode.
- `npm test`: PASS.
- `npm run release:build`: PASS.
- Build: 472 archivos; `web = dist = Android` según gate de build.
- Android preflight: 4/5; falta únicamente firma local privada `keystore.properties` por diseño.
- iOS `swiftc -parse`: PASS.
- Plist/entitlements iOS: PASS.
- Secret/signing scan: PASS.
- PDFs: 16/16 abiertos y preflight limpio; master renderizado/inspeccionado visualmente.

## 8. Fuera de alcance deliberadamente
No se ha implementado todavía:
- menú/ruta productiva de KOMBAX Guías;
- checkout/venta de Consultoría;
- entitlements de Formación;
- Showcase Commerce nuevo;
- KOMBAX Finance multientidad;
- Home de cuatro tarjetas;
- directorio/rankings;
- nueva Finanzas Premium en acordeones.

Todo permanece en el Plan Maestro pendiente y debe continuar de forma acumulativa desde este paquete.
