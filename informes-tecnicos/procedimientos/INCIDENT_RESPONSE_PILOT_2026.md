# KOMBAX — respuesta a incidentes del piloto 2026

**Corte:** 27/09/2026. **Alcance previsto:** cuatro clubes, aproximadamente veinte competidores verificados y usuarios asociados. Este documento actualiza para esta cohorte el procedimiento histórico de [`docs/03_OPERATIONS/INCIDENT_RESPONSE_RUNBOOK_20070.md`](../../docs/03_OPERATIONS/INCIDENT_RESPONSE_RUNBOOK_20070.md). No acredita que los canales de contacto, alertas o ensayos estén operativos.

## Prioridad y actuación

| Prioridad | Ejemplo | Acción inicial |
|---|---|---|
| P0 | Fuga entre clubes, escalada de privilegios, pérdida de datos, exposición de secretos o riesgo grave para menores | Suspender la operación afectada, preservar evidencia, avisar al responsable y bloquear incorporación de datos reales hasta confirmar contención. |
| P1 | Login general, alta o vinculación de club, invitaciones, recuperación de cuenta o backend principal inutilizable | Congelar despliegues, identificar versión y alcance, corregir o revertir con prueba dirigida antes de reabrir. |
| P2 | Flujo secundario degradado sin riesgo de seguridad o integridad | Registrar, asignar responsable y programar corrección durante el piloto. |
| P3 | Defecto cosmético o mejora | Registrar para después del piloto. |

## Secuencia mínima

1. **Detectar:** revisar health, logs Supabase Auth/DB/Edge, incidentes cliente y monitor externo cuando exista. Registrar hora UTC, versión y señal observada.
2. **Delimitar:** identificar clubes, usuarios y funciones afectadas sin copiar datos personales ni secretos al incidente.
3. **Contener:** pausar solo el flujo comprometido; revocar sesiones o credenciales afectadas cuando corresponda. No desactivar RLS para recuperar servicio.
4. **Congelar:** detener cambios simultáneos y conservar commit, migraciones, logs y snapshot pertinente.
5. **Recuperar:** aplicar corrección mínima o revertir con procedimiento probado. Nunca ensayar restauración sobre producción.
6. **Comunicar:** contactar a los clubes afectados mediante canal comprobado; valorar obligaciones de privacidad y protección de menores con el responsable competente.
7. **Verificar:** repetir la prueba que detectó la incidencia, una prueba de no regresión y una prueba de aislamiento entre clubes.
8. **Cerrar:** documentar causa, impacto, tiempos, responsable, decisión y acciones preventivas en `informes-tecnicos/piloto/KOMBAX_PILOT_2026.md`.

## Condición de operatividad

El procedimiento está **documentado**, pero `incident_runbook` debe permanecer **NO VERIFICADO** hasta ejecutar al menos un simulacro fechado, confirmar responsable y suplente, comprobar entrega de los canales de aviso y registrar tiempo de detección, escalado y resolución. El runbook histórico menciona dos clubes y evidencias del 24/08/2026; esas evidencias no certifican la cohorte de cuatro clubes ni la operación actual. La monitorización externa sigue pendiente según `docs/03_OPERATIONS/MONITORING_RUNBOOK_20072.md`.

La decisión del propietario de no activar TOTP durante el piloto se respeta. Ante sospecha de compromiso de la cuenta Owner con contraseña convencional, la contención debe incluir cierre de sesiones privilegiadas y cambio de credencial; la eficacia de ese procedimiento aún requiere ensayo.
