# KOMBAX RC13 · build 20072 · QA de seguridad, RLS y separación de roles

Fecha de cierre técnico: 2026-08-23.

## Método

Las pruebas de autorización se ejecutaron contra el proyecto Supabase real usando sesiones simuladas por `request.jwt.claim.sub` dentro de transacciones SQL reversibles. Las asignaciones sintéticas de Tutor, Moderador y Verificador se realizaron únicamente dentro de `BEGIN … ROLLBACK`, sin dejar datos persistentes.

No se incluyen UUID, emails ni datos personales en este informe.

## Resultados

| Control | Resultado | Evidencia resumida |
| --- | --- | --- |
| Dirección Club A → datos Club A | PASS | Ve sus socios y cuotas esperados. |
| Dirección Club A → Club B | PASS negativo | 0 socios y 0 cuotas de otro club. |
| Monitor | PASS | 0 acceso transversal y 0 finanzas no autorizadas en la muestra real. |
| Alumno | PASS | Solo ve su propio socio, cuotas y pagos; 0 datos económicos ajenos. |
| Tutor sintético | PASS | Solo ve al menor vinculado y sus cuotas; 0 socios/cuotas ajenos. |
| Moderador sintético | PASS | Cola de moderación permitida; eliminación bloqueada; sin SELECT directo de chats/documentos de verificación. |
| Verificador sintético | PASS | Identidad de verificador válida; moderación y eliminación bloqueadas; sin SELECT directo de chats. |
| Owner sin MFA | PASS negativo | Cola de eliminación y administración global bloqueadas con `PLATFORM_ADMIN_REQUIRED`. |
| Verificador → borrar documento privado | CORREGIDO / PASS | Migración 128 elimina DELETE del Verificador; mantiene revisión de solo lectura. |
| Gate legal global | PASS | Migración 129: antes de aceptar `required:true`; tras aceptación reversible, `required:false`. |
| Términos vs Privacidad | PASS | Términos se registran como aceptación; privacidad como lectura/reconocimiento, separada de consentimientos opcionales. |

## Storage

Buckets privados confirmados para Comunidad, documentos, justificantes, multimedia restringida, verificación, perfil y perfil deportivo. Los buckets deliberadamente públicos son `club-public-media` y `kombax-public-media`.

El inventario encontró objetos candidatos a huérfanos históricos. No se borraron automáticamente porque una ausencia en el primer mapa de referencias no prueba por sí sola que un objeto carezca de uso histórico o contractual. Se creó `STORAGE_ORPHAN_CLEANUP_RUNBOOK_20072.md` con inventario, comprobación y periodo de gracia.

## RPC públicos SECURITY DEFINER

Se revisaron los RPC anónimos que permanecen ejecutables:

- directorio público de clubes;
- catálogo público necesario para alta;
- categorías Showcase;
- listado Showcase.

Sus contratos devuelven únicamente campos públicos necesarios para navegación/registro. No exponen miembros, emails privados, teléfonos privados, documentos, pagos ni permisos. Se mantienen abiertos intencionadamente.

## Conclusión

**Aislamiento multiclub y separación de roles principales: PASS para los controles ejecutados.**

No sustituye el QA E2E posterior al deploy: tras publicar la candidata se repetirán pruebas desde navegador/APK con cuentas separadas de QA.
