# KOMBAX 20.101 R26 · Privacy, Authorized Support & Events Navigation

## Cambios
- Nuevo centro **Privacidad y soporte** reutilizable para Club, cuenta personal y perfiles profesionales/directos.
- Contacto canónico de soporte: `soporte@kombax.es`.
- Autorizaciones temporales de soporte con código de un solo uso visible al cliente, expiración, ticket opcional, alcance y revocación.
- El código se almacena únicamente como SHA-256; el texto plano solo se devuelve al crearlo.
- La reclamación del código por el futuro agente de soporte es `service_role`-only.
- Auditoría del ciclo de autorización/claim/revocación.
- Se conserva el acceso privilegiado independiente del Administrador General/Owner y su arquitectura de auditoría existente.
- Events: filtros, cartelera cacheada y posición de scroll se conservan al volver a la sección, con revalidación posterior del servidor.
- Cache bust web/service worker actualizado a R26.

## Backend
- Migración 194: `kombax_authorized_support_privacy_20101_r26`.
- Migración 195: `kombax_authorized_support_pgcrypto_fix_20101_r26`.
- La 195 corrige de forma compensatoria la resolución de `pgcrypto.digest` en el esquema `extensions`; no se borró historial.

## No incluido
- No se ha implementado todavía el agente IA que lee/responde `soporte@kombax.es`.
- No se ha desplegado Netlify ni realizado push a GitHub.
- No se ha generado ni afirmado APK/AAB firmada.
