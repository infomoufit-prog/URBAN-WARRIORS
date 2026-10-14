# QA fase 0 — Pruebas efectuadas

| Prueba | Resultado | Naturaleza |
|---|---|---|
| ZIP CRC/integridad completa | PASS | Archivo real local |
| Nombres de los 5.731 archivos vs GitHub | PASS | Árbol remoto vs ZIP local |
| Código comparado por Git blob SHA en 16 rutas | 11 diferentes, 5 iguales | Detección de diferencias, **no** fallo |
| web/dist/Android, nueve rutas clave | PASS | Hash SHA-256 |
| Meta/Instagram FIX20 | 23/23 PASS | Proveedor externo simulado |
| Workspace FIX14 | 13/13 PASS | Test unitario |
| Material/inventario R89 | 52/52 PASS | Estático/contrato |
| Piloto estabilización R118 | PASS | Estático/regresión |
| Release metadata | PASS | Metadatos |
| Owner performance R114 | 12/12 PASS | Estático/regresión |

### Límites

No se ha ejecutado toda la batería de `npm test`, no se han realizado pruebas E2E autenticadas contra Netlify, no se ha enviado contenido a Instagram, no se han modificado registros de Supabase y no se ha compilado un Android nuevo.
