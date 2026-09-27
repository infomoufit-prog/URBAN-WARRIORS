# KOMBAX · QA Scorecard · Expansión territorial de Guías

**Release base:** R81 build 20134  
**Fecha:** 21/09/2026

| Gate | Resultado | Evidencia |
|---|---|---|
| Unidades territoriales | PASS · 19/19 | catálogo territorial |
| Fuentes oficiales mínimas | PASS | >=2 referencias oficiales por territorio |
| Diferenciales verificados | PASS | >=2 por territorio |
| Frontera de caso específico | PASS | >=1 por territorio |
| CTA KOMBAX Consultoría | PASS | 19/19 |
| Política no-invención | PASS | catálogo + fuentes + tests |
| Gate territorial automatizado | PASS · 182/182 | `scripts/test-kombax-preblock-territories.mjs` |
| PDFs individuales | PASS · 19/19 | preflight PDF |
| PDF maestro | PASS · 21 páginas | render + inspección visual |
| `npm test` acumulativo | PASS | `qa/territorial_guides/FULL_NPM_TEST.log` |
| Legal gate | PASS | release build |
| `npm run release:build` | PASS | `qa/territorial_guides/RELEASE_BUILD.log` |
| Paridad web/dist/Android | PASS · 472 archivos | build determinista |
| Android release preflight | 4/5 esperado | falta solo firma privada local |
| iOS Swift parse | PASS | `qa/territorial_guides/MOBILE_PREFLIGHT.log` |
| iOS plist/entitlements | PASS | mismo log |
| Secret scan | PASS · 0 | `qa/territorial_guides/SECRET_SCAN.log` |

## Nota de seguridad documental

`verified` significa que el diferencial está respaldado por la fuente oficial indicada. `case` no afirma la existencia de un permiso concreto: señala que la respuesta final depende de datos no universales y debe verificarse con la autoridad, federación, recinto o profesional aplicable.
