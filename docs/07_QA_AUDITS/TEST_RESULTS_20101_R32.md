# Test Results · KOMBAX 20.101 R32

## Regresión global
Comando: `npm test`
Resultado: EXIT 0.

- 152 scripts de prueba encadenados.
- 2.258 líneas OK/PASS en el log.
- 0 líneas FAIL.
- R28: 13/13 PASS.
- R29: 9/9 PASS.
- R30: 12/12 PASS.
- R31: 15/15 PASS.
- R32: 36/36 PASS.

Log completo: `TEST_RESULTS_20101_R32_FULL.log`.

## Ajustes de tests históricos durante R32
Dos pruebas tenían supuestos ya obsoletos:
1. R14 exigía que un JKS viajara dentro del proyecto. Se corrigió para exigir configuración de firma externa y ausencia del JKS empaquetado.
2. R31 exigía literalmente cache `r31`. Se corrigió para aceptar R31 o posterior.

Estos cambios son del harness; no modifican funcionalidad para forzar un PASS.
