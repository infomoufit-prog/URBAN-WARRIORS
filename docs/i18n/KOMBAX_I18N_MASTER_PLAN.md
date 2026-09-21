# KOMBAX · Plan maestro de internacionalización

Fuente de verdad de esta cadena: **ZIP acumulativo recibido**. La cadena autorizada es R73 master → B01 F01-05 → B02 F06-10 → B03 F11-15 → B04 F16-20 FINAL.

## Principios permanentes

- Un producto, un código y una lógica de negocio para N idiomas.
- Locales iniciales: `es`, `en`, `fr`, `pt`, `it`, `de`, `th`, `fil`.
- Maestro: `es`. Fallback: seleccionado → `en` → `es`.
- No traducir automáticamente contenido de usuarios ni texto incrustado en assets.
- No traducir rutas técnicas durante estas 20 fases.
- KOMBAX, KOMBAX Social, KOMBAX Showcase, KOMBAX Events, KOMBAX Assist y KOMBAX Migrations son nombres comerciales invariantes.
- Idioma, país, moneda, timezone, jurisdicción y versión legal son dimensiones separadas.
- No modificar IDs QR/ticket por idioma.
- No desplegar automáticamente frontend, GitHub, Netlify, Google Play ni migraciones Supabase.

## Bloques

1. F01-05 Fundación: baseline, inventario, núcleo, español maestro, selector/persistencia/fallback. **COMPLETADO EN ESTE ZIP.**
2. F06-10 Idiomas y formatos: inglés; FR/PT/IT/DE; TH/FIL; formatos regionales; validadores/cobertura.
3. F11-15 Integración: Social; Showcase/Commerce; Events/Ticketing; Assist/Migrations; email/push/documentos/legal.
4. F16-20 QA/release: visual; E2E; seguridad/integridad; rollout; freeze final.

Nunca ejecutar más de cinco fases por conversación y siempre cerrar con ZIP completo verificado.

## Current cumulative status — after Block 2

- Completed through: **Phase 10**.
- Next phase: **Phase 11 — KOMBAX Social**.
- Supported locales: ES, EN, FR, PT, IT, DE, TH, FIL.
- Publicly enabled locales: **ES, EN**.
- Catalogs: 229/229 master keys populated for all 8 locales.
- Deep module migration remains intentionally assigned to F11–F15; catalog completeness is not used as a substitute for source migration or visual/E2E QA.


## Estado acumulativo B03 F11–F15
Bloque 3 integrado. Continuidad siguiente: F16–F20 sobre el ZIP B03 exclusivamente.
