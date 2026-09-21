# KOMBAX Security Policy · RC13 Pilot

## Principios obligatorios
- Un tenant nunca debe leer o modificar datos privados de otro tenant.
- El contexto de Club no debe heredar chats/identidades privadas de otro perfil gestionado por la misma cuenta.
- El cliente nunca recibe `service_role` ni secretos de infraestructura.
- Owner/Soporte es temporal, explícito, auditado y, desde 20.084 tras activación, exige MFA AAL2.
- Los cambios financieros conservan trazabilidad e idempotencia; no se emite recibo antes de pago completo.
- Los documentos e informes privados no se publican en buckets públicos.
- Cualquier cambio de autorización, RLS, Storage, Auth, Edge Function o gateway requiere regresión multiclub.

## Incidente de máxima prioridad
Se considera crítico cualquier acceso cruzado entre clubes, compromiso Owner/service_role, exposición de documentos/finanzas, secreto publicado o alteración masiva de datos. Aplicar `docs/INCIDENT_RESPONSE_MINIMUM_20084.md`.

## Release
La existencia del código 20.084 no equivale a aprobación de producción. El gate `app_kombax_security_status_v149` y el QA de dos clubes deben estar completos antes de habilitar el piloto.
