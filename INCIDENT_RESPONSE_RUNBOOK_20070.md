# KOMBAX 20077 · respuesta ante incidentes

## Contactos operativos del piloto

- Responsable primario: **BRYAN RIVERA GREY**.
- Seguridad: **seguridad@kombax.es**.
- Soporte: **soporte@kombax.es**.
- Privacidad: **privacidad@kombax.es**.
- Child Safety: **childsafety@kombax.es**.

No se registra un teléfono o suplente hasta disponer de un dato real aprobado. Durante el piloto de 2 clubes no se declara cobertura 24/7.

## Procedimiento

1. **Detectar:** revisar health, telemetría cliente, Auth, API, Storage, Edge Functions, cron y monitor externo cuando esté activo.
2. **Clasificar:** S1 exposición/pérdida/aislamiento roto; S2 acceso u operación crítica bloqueada; S3 degradación sin pérdida; S4 defecto menor.
3. **Contener:** cerrar sesiones administrativas cuando corresponda, rotar credenciales comprometidas, pausar el flujo afectado y preservar evidencia mínima.
4. **Investigar:** correlacionar `request_id`, build, hora UTC, cuenta y acción auditada. Nunca copiar tokens, OTP, contraseñas, service-role keys o enlaces de Auth de un solo uso al ticket.
5. **Recuperar:** restaurar solo desde copia verificada o desplegar corrección con validación y plan de reversión. Nunca ejecutar un restore sobre producción para probar el procedimiento.
6. **Comunicar:** utilizar los contactos jurídicos/operativos aprobados; valorar y documentar las obligaciones de notificación a AEPD y afectados cuando sean aplicables.
7. **Cerrar:** registrar causa raíz, alcance, decisiones, evidencias, pruebas de recuperación y prevención.

## Escalado mínimo del piloto

- S1: detener la operación afectada, avisar al responsable primario y `seguridad@kombax.es` de inmediato; si afecta a menores, activar también Child Safety.
- S2: intervención prioritaria el mismo periodo operativo; no reabrir el flujo sin prueba de corrección.
- S3: corregir y verificar durante el piloto, con seguimiento en el siguiente control de health/logs.
- S4: registrar como deuda no bloqueante si no afecta seguridad, privacidad, datos, pagos o menores.

## Criterio de cierre

El runbook queda **operativo para piloto** cuando existe responsable real, canales funcionales, clasificación, contención y procedimiento de recuperación. La ausencia de un monitor externo independiente se registra separadamente en `MONITORING_RUNBOOK_20072.md` y no debe ocultarse marcando monitorización como completa.
