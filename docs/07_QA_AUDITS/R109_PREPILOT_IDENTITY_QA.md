# QA R109 · Cierre pre-piloto de identidad

## Baseline antes de cambios

- Account/profile policy R100: **15 escenarios PASS**.
- Verified Competitor R102: **PASS**.
- Profile Matrix R32: **36/36 PASS**.
- R108 gate: **10/10 PASS**.

## R109

- `test-kombax-20162-r109-prepilot-identity.mjs`: **25/25 PASS**.
- R58 identity/media: **19 PASS**.
- R62.6 Social Discovery: **22 PASS**.
- R100 account policy: **15 PASS**.
- R102 verified competitor: **PASS**.
- R28 capability: **13/13 PASS**.
- R32 matrix: **36/36 PASS**.
- R108 historical gate: **10/10 PASS** (marcadores históricos conservados).
- Sintaxis de módulos modificados: **PASS**.
- All-8 activation gate: **PASS**, actualizado para permitir crecimiento por encima del baseline histórico manteniendo paridad entre idiomas.

## Comparación de gates históricos no verdes

| Gate | R108 original | R109 | Resultado |
|---|---:|---:|---|
| R79 full product audit | 264 unresolved | 264 unresolved | Sin regresión |
| Runtime copy audit | 250 unresolved | 250 unresolved | Sin regresión |
| `i18n-validate` | 100 % keys + hardcode `customer-operations.js`, exit 1 | igual | Sin regresión |
| R72 commercial continuity | 13/18 | 14/18 | Mejora |
| R72 identity/spectator | 12/15 | 13/15 | Mejora |
| R72 Seller Center | 12/13 | 13/13 | Mejora |
| R72 Events Operations | 14/15 | 15/15 | Mejora |
| R72 Sidebar accordions | 9/9 | 9/9 | Igual |
| R72 Reputation | 14/14 | 14/14 | Igual |

Los fallos heredados no se ocultan ni se convierten artificialmente en PASS. R109 añade pruebas específicas y compara contra el ZIP R108 original para distinguir regresión de deuda histórica.

## Android

`node scripts/build.mjs` confirma **618 archivos con paridad web = dist = Android**. El intento de `:app:assembleDebug` no llegó a compilar porque Gradle Wrapper necesita descargar Gradle 8.11.1 y el entorno de ejecución no tiene acceso de red a `services.gradle.org`. Se clasifica como validación externa, no como fallo funcional R109.
