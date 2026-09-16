# PROMPT MAESTRO DE CONTINUIDAD · KOMBAX RC13 build 20.098

Trabaja exclusivamente sobre **KOMBAX RC13 build 20.098 · Events Large Format Experience with Local Signing** como nueva fuente de verdad.

## Estado
- web/PWA/Android: build 20098.
- Supabase real: migraciones Eventos 159–174 aplicadas; 173/174 pertenecen a 20.098.
- `health` productivo sigue 20094 hasta deploy; source local 20098.
- `event-media-url` sigue siendo el firmador de media privada.
- Urban Warriors todavía NO tiene `events.public.organize`; activar solo post-deploy con `POSTDEPLOY_ENABLE_URBAN_WARRIORS_EVENTS_20098.sql`.
- La Federación QA de la misma cuenta no puede mezclarse con Urban Warriors gracias a v171/v172.
- Mi Club > Eventos sigue privado y separado.
- Espectador continúa cerrado.

## Qué introdujo 20.098
- grandes anuncios de evento tipo cartel;
- Main Event teaser;
- estados independientes evento/inscripción/tickets;
- venue/dirección/mapa/acceso/aforo;
- tickets/inscripción/streaming/web mediante enlaces HTTPS externos;
- detalle de segundo nivel: Información · Main Event · Fight Card · Peleadores · Organización · Highlights;
- backend v173 y hardening ACL v174.

## Gates ya superados
- npm test: PASS completo.
- npm run build: PASS.
- web = dist = Android: 102 archivos idénticos.
- legal gate: PASS.
- Android preflight: 4/5; falta `keystore.properties` local, no el JKS.
- JKS real está en `LOCAL_RELEASE_SIGNING/kombax-release.jks`.

## Regla de siguiente intervención
Antes de tocar código: plan previo detallado. Mantener 20.098 congelada y crear build superior. No desplegar ni activar Urban Warriors sin autorización expresa. No introducir pagos/ticketing internos sin diseño legal/financiero específico.
