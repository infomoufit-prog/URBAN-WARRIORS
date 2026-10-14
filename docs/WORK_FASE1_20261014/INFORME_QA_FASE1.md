# QA Fase 1

## PASS, verificación local

| Prueba | Resultado | Modalidad |
|---|---|---|
| Selector, roles simultáneos, recuperación, aislamiento multiclub, permisos negativos | 26/26 | JS unitario + integraciones estáticas |
| Finanzas familiares por alumnos autorizados, queries protegidas, casos vacíos/IDs inválidos | 17/17 | JS unitario + contratos estáticos |
| Gateway de cuenta/espacios FIX14 | 13/13 | Unitario |
| Perfil público personal R118 | PASS | Unitario/estático |
| Piloto estabilización R118 | PASS | Estático |
| Material y stock R89 | 52/52 | Estático |
| Owner R114 | 12/12 | Estático |
| Metadatos release | PASS | Estático |
| Sintaxis de JS completo de `web/js` | PASS | Sintáctico |
| Equivalencia web/dist/Android (12 módulos) | PASS | Byte a byte SHA-256 |

## Pendiente / límite

- Pruebas E2E con roles reales y RLS: no efectuadas.
- `npm test` completo no ejecutado por falta de dependencias de Node en la copia.
- Pruebas con PGlite no ejecutadas (`ERR_MODULE_NOT_FOUND`).
- APK/AAB no recompiladas.
- Test histórico R43 tiene una expectativa estática incumplida en `managed-profile-hub.js`, un archivo que esta fase no modifica. No modificar ese módulo solo para pasar una prueba antigua sin auditar la regla real de migraciones de Federación.
- Ningún despliegue de Netlify, escritura Supabase, publicación Meta ni push GitHub.

## Siguiente puerta de calidad

No publicar esta fase como validada en producción sin comprobar con perfiles pilotos autorizados el ciclo completo de registro, cambio de rol, selección de alumno, cuotas familiares y recuperación tras cierre/reapertura en móvil.
