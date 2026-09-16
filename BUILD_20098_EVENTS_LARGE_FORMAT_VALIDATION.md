# KOMBAX RC13 build 20.098 · Events Large Format Experience · Validation

## Resultado
**PASS** como candidata local completa de código/Android/PWA y backend compatible.

## Objetivo del release
20.098 transforma KOMBAX Eventos en una experiencia claramente distinta de Showcase:
- portada con anuncios de evento grandes, de una sola columna y tratamiento de cartel;
- teaser del Main Event directamente en la portada cuando ya existe Fight Card;
- segundo nivel completo al abrir el evento;
- estados separados para fase del evento, inscripciones y venta de entradas;
- venue, dirección, mapa, acceso/parking, aforo, tickets externos, inscripción externa, streaming y web oficial;
- navegación interior: Información · Main Event · Fight Card · Peleadores · Organización · Highlights.

## Contrato comercial
KOMBAX no procesa ni cobra entradas en 20.098. La venta y la inscripción externas se enlazan mediante HTTPS al proveedor configurado por el organizador. Esto evita introducir una pasarela financiera/ticketing no auditada.

## Seguridad y aislamiento
- `Mi Club > Eventos` permanece como dominio privado separado.
- La migración 173 no consulta `eventos_competicion`, `evento_participantes` ni `evento_combates`.
- Las mutaciones v173 delegan primero en `app_kombax_eventos_mutate_v171`, conservando el aislamiento de workspace de 20.097.
- Direct SELECT sobre `kombax_eventos_publicos` sigue revocado para `anon` y `authenticated`.
- Mutación v173: `anon = false`, `authenticated = true`.
- Helpers de estado v173 endurecidos por migración 174: solo `service_role`; el público consume estados mediante los lectores curados v173.

## QA
- `node --check` en repositorio/UI/test 20.098: PASS.
- `npm run test:20098`: PASS.
- `npm test`: PASS completo, incluyendo Finance, Social, Showcase, Owner/Admin, Mi Club y Eventos 20.090–20.098.
- `npm run build`: PASS.
- build determinista: **102 archivos · web = dist = Android**.
- `npm run release:legal-gate`: PASS.
- Android preflight: 4/5; único pendiente: creación local de `android/keystore.properties` con las credenciales privadas. El JKS real viaja en `LOCAL_RELEASE_SIGNING/`.

## Backend real
Aplicadas en Supabase principal:
- 171/172 · workspace isolation (heredadas 20.097)
- 173 · Large Format Experience
- 174 · helper RPC least privilege

`health` productivo se mantiene deliberadamente en build 20094 hasta que el frontend 20.098 se despliegue. El source local de `health` ya está en 20098.

## Urban Warriors
`events.public.organize` permanece **desactivado** para Urban Warriors en producción a fecha de cierre. La activación controlada está en `POSTDEPLOY_ENABLE_URBAN_WARRIORS_EVENTS_20098.sql` y debe ejecutarse solo después del deploy de una frontend 20.097+ (recomendado 20.098).

## Visual hotfix during local candidate validation

- Corrected KOMBAX Eventos brand symbol contrast before deployment.
- The white KOMBAX symbol no longer sits on a near-white tile; it now uses a dark premium plate with subtle red/cyan illumination and visible white mark.
- No functional/backend contract changed.
- `npm run build` re-run successfully after the correction: `OK build 102 archivos · web = dist = Android`.
