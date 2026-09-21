# R26 · Modelo de Privacidad y Acceso de Soporte

## Principios
1. Los datos privados del club siguen protegidos por el tenancy/RLS existente.
2. El soporte ordinario se habilita mediante autorización temporal del titular autorizado.
3. Una autorización tiene sujeto, duración, scopes, referencia de ticket y estado.
4. El código de 6 dígitos no se almacena en texto plano; solo se guarda SHA-256.
5. El futuro agente IA solo podrá reclamar una autorización desde backend con `service_role`.
6. `authenticated` no puede reclamar códigos ni leer directamente las tablas internas de autorización/auditoría.
7. El Administrador General conserva su vía privilegiada independiente para administración, seguridad, moderación, cumplimiento e incidencias críticas. R26 no reduce ese control; la arquitectura existente de sesiones/auditoría privilegiada se mantiene.

## Scopes disponibles
- `support.read`
- `support.write`
- `finance.read`
- `documents.read`
- `minors.read`

## Sujetos
- `club`: Dirección o Coordinación activa; Administrador General también puede gestionar.
- `direct_profile`: titular o gestor owner/admin; Administrador General también puede gestionar.
- `account`: titular de la cuenta; Administrador General también puede gestionar.

## Ubicación UX
- Mi Club → Ajustes → Privacidad y soporte.
- Mi perfil → Avisos y privacidad → Privacidad y soporte.
- Mis perfiles → cuenta / club gestionado / perfil profesional → Privacidad y soporte.

## Transparencia
La UI informa de que el primer contacto puede ser atendido por un asistente virtual de soporte KOMBAX y de que la moderación pública y las facultades administrativas excepcionales son independientes de la autorización de soporte ordinario.
