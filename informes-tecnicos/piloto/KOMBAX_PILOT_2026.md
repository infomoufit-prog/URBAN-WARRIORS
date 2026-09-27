# KOMBAX — registro vivo del piloto 2026

Periodo objetivo: 01/10/2026–15/11/2026. Cohorte prevista: cuatro clubes, aproximadamente veinte competidores verificados y sus usuarios asociados. Este registro no implica que la cohorte esté dada de alta.

## Estado del release gate

**27/09/2026: NO-GO técnico.** El detalle de seguridad y evidencia se encuentra en [`../seguridad/SUPABASE_SECURITY_GATE_2026-09-27.md`](../seguridad/SUPABASE_SECURITY_GATE_2026-09-27.md) y en el informe de release gate entregado fuera del checkout. Netlify y Google Play permanecen a cargo del propietario, sin certificación en este corte.

| Área | Estado a este corte | Evidencia o límite |
|---|---|---|
| Seguridad Supabase | FAIL | Tres fugas Showcase corregidas, auditoría RPC y controles P1 aún abiertos. |
| Auth | FAIL | 0 factores MFA Owner verificados; flujos completos sin nueva prueba. |
| RLS / Multiclub | NOT TESTED para cuatro clubes | Cobertura SQL previa de dos clubes; falta matriz HTTP real. |
| Competidores / Social / Events / Showcase | NOT TESTED integral | Presencia de datos demo y pruebas estáticas no certifican flujos completos. |
| Assist / Migrations | NOT TESTED integral | 0 monederos y 0 ejecuciones IA medidas en proyecto real. |
| PWA / Android | NOT TESTED integral | Build local existe; falta dispositivo y artefacto firmado. |
| Backup | FAIL | Integridad 102/102; falta copia externa y restauración aislada. |
| Monitoring | FAIL | Logs consultables; control readiness sin verificar ni alerta acreditada. |

## Incidencias y correcciones

| Fecha | Prioridad | Área | Resultado | Evidencia |
|---|---|---|---|---|
| 27/09/2026 | P1 | Showcase / Data API | Filtrado de detalles de inventario de borradores por publicación o gestor autorizado. | Migraciones 290 y 291; pruebas SQL transaccionales de público, gestor y otro club. |
| 27/09/2026 | P1 | Showcase / cumplimiento | Consulta de datos de vendedor y moderación de borrador ajeno denegada. | Migración 292; reproducción previa y tres pruebas transaccionales posteriores. |
| 27/09/2026 | P1 | Recuperación | Copia interna verificada, restore externo y aislado aún pendientes. | Snapshot `20077-2026-09-27T07-59-52-702Z`, 102/102 artefactos. |
| 27/09/2026 | P1 | Auth Owner | El propietario difiere TOTP hasta después del piloto. Se mantiene contraseña convencional y el riesgo se documenta; no se activa AAL2. | Decisión explícita del propietario en esta conversación; estado real MFA 0 factores verificados. |

## Condiciones abiertas antes de incorporar datos reales

- Evaluación y prueba de controles compensatorios para el Owner sin TOTP durante el piloto; reabrir MFA después del 15/11 por decisión del propietario.
- Exportación fuera del proyecto y ensayo de restauración aislada con tiempos medidos.
- Pruebas HTTP REST/RPC/Storage con cuatro identidades de club y recursos ajenos.
- Verificación fechada de SMTP, responsable legal, monitorización e incident runbook.
- Ensayo funcional de altas, invitaciones, miembros, competidores, Social, Events, Showcase, Assist y Migrations con saldo de piloto.
- Smoke test de la versión real desplegada cuando Netlify esté disponible; Android firmado y probado cuando exista artefacto.

Durante el piloto, añadir cada incidencia con fecha, severidad, versión, alcance, corrección, prueba y decisión. No mezclar feedback, bugs y solicitudes comerciales.
