# QA Fase 3

**Estado:** pruebas de código y consultas SQL seguras superadas; E2E real pendiente.

## Superado
- 49/49 `scripts/test-kombax-phase3-finance-void.mjs`.
- 32/32 `scripts/test-kombax-phase2-inscripciones-licenses.mjs`.
- 26/26 `scripts/test-kombax-phase1-multi-space.mjs`.
- 17/17 `scripts/test-kombax-phase1-finance-scope.mjs`.
- 52/52 `scripts/test-kombax-20142-r89-inventory-lifecycle.mjs`.
- `scripts/test-kombax-20177-r118-pilot-stabilization.mjs`: PASS.
- `scripts/test-release-metadata.mjs`: PASS.
- `node --check` para todos los JS `web/js`: PASS.
- Mirrors exactos de los cinco módulos modificados entre web/dist/Android: PASS.
- Supabase: RPC y privilegios comprobados, saldo cero para estados anulados, auditoría vacía y datos existentes intactos.

## Pendiente
- Pruebas de autorización con JWTs de Dirección/Tesorería y denegación en roles Monitor/Secretaría sin tocar cargos reales.
- Prueba de anulación sobre **cuota de test aislada** con revisión previa; confirmar saldos, métricas y trazabilidad.
- Prueba de carrera de dos peticiones y reintentos de red en entorno controlado.
- E2E PGlite y `npm test` completo (dependencias no instaladas en esta copia).
- Revisión fiscal de los flujos que afectan recibos emitidos o pagos bancarios (no abordados).
- Pruebas visuales y compilación Android.
