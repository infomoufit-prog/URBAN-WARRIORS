# QA Scorecard · KOMBAX Guías territoriales profesionales + Prompt Maestro
## 21/09/2026

| Gate | Resultado |
|---|---|
| Territorios indexados | 19/19 PASS |
| PDFs territoriales individuales | 19/19 PASS |
| Dossier maestro detallado | PASS · 141 páginas |
| Páginas totales PDFs individuales | 156 |
| Secciones profesionales obligatorias | 19/19 PASS |
| CTA/frontera KOMBAX Consultoría | 19/19 PASS |
| Fuentes identificadas | PASS |
| Placeholders TODO/TBD/Lorem | 0 |
| Precios Consultoría inventados | 0 |
| Test específico detallado | 147/147 PASS |
| Test bloque previo original | 69/69 PASS |
| Test territorial anterior | 182/182 PASS |
| `npm test` acumulativo | PASS |
| `npm run release:build` | PASS |
| Build web/dist/Android | PASS · 472 archivos |
| Android preflight | 4/5 · solo falta firma local privada |
| iOS `swiftc -parse` | PASS |
| Prompt Maestro MD | PASS |
| Prompt Maestro PDF | PASS · 15 páginas |
| Preflight PDFs | 21/21 openable, no cifrados, no escaneados |

## Notas

El preflight Android no incluye `keystore.properties` por diseño de seguridad. No debe incorporarse al ZIP.

La compilación/firma iOS final sigue siendo un gate externo macOS/Xcode/Apple Developer.

No se han realizado operaciones de pago reales durante este bloque.
