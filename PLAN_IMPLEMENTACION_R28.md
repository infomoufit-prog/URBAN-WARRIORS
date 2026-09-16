# PLAN_IMPLEMENTACION_R28 · PROFILE & CAPABILITY FOUNDATION

## Base
- Fuente: KOMBAX 20.101 R27 · Support Email Frontend.
- SHA-256 verificado: `b1093f46d4dae4dbcba0da9c9a3b5d5596d42b255e9d531638fc3774c82146c2`.
- Backend principal: `poggsobhtutbuagjiydc`.
- Hallazgo previo: el backend principal ya contiene las migraciones R28 `kombax_profile_capability_foundation_20101_r28`, `kombax_profile_professional_spectator_mutations_20101_r28` y `kombax_profile_capability_advisor_hardening_20101_r28`; por tanto R28 se reconcilia en código/paquete y no se reaplica destructivamente.

## Objetivo
Abrir Profesional y Espectador, separar taxonomía/capacidades de planes, añadir age gates y resolver capacidades efectivas desde backend sin alterar Club/Miembro ni convertir Competidor en Profesional.

## Alcance
- Registry único de perfiles y especialidades.
- Profesional 18+ con especialidad principal y secundarias controladas.
- Espectador 16+, no publicador y privado por defecto.
- RPC v196 como fuente de verdad para perfiles/capabilities.
- Gateway y repositorios migrados de v072 a v196 con fallback controlado donde proceda.
- Cache de capabilities por subject e invalidación explícita.
- Privacidad/soporte sin duplicación.

## No alcance
- Finanzas Profesionales.
- Delegaciones Manager.
- Operativa por subtipo más allá del perfil básico.
- Expediente sanitario.
- Deploy GitHub/Netlify.

## Riesgos
1. Divergencia R27 local vs R28 ya vivo: mitigación por snapshot de catálogo y reconciliación, sin reejecutar DDL existente.
2. Bypass por frontend: todas las mutaciones sensibles se mantienen en RPC autenticadas.
3. Mezcla de identidad al cambiar subject: cache key por profile_id e invalidación.
4. Regresión de Competidor/Marca/Federación: v196 delega a v072 para tipos heredados.

## Archivos previstos
- `web/js/core/profile-registry.js` (nuevo)
- `web/js/core/capability-resolver.js` (nuevo)
- `web/js/core/repositories.js`
- `web/js/core/identity-context.js`
- `web/js/modules/gateway.js`
- `web/index.html`
- `web/service-worker.js`
- `scripts/test-kombax-20101-profile-capability-r28.mjs` (nuevo)
- `package.json`
- documentación R28.

## Backend verificado antes de tocar código
- Constraint de `perfiles_kombax_directos.tipo` ya incluye `profesional` y `espectador`.
- Tablas v196 existentes: especialidades, perfil profesional, especialidades secundarias, edad privada y capacidades base.
- RPC v196 existentes: taxonomy, age, capabilities, mis_perfiles, mutation y validación.
- Capabilities R28 existentes: `professional.profile.manage`, `professional.credentials.manage`, `profile.settings.manage`, `social.read`, `events.public.read`, `events.public.engage`.

## QA y gates
- Regresión R27 previa: PASS físico.
- Profesional <18 bloqueado por contrato de RPC.
- Espectador <16 bloqueado por contrato de RPC.
- Espectador no solicita verificación.
- Competidor no figura como especialidad Profesional.
- `mine()` usa v196.
- `saveProfile/saveApplication/submit/review` usan v196.
- Capability resolver central y cache por profile id.
- npm test + build + paridad + Android preflight.
- No avanzar a R29 si falla cualquier gate R28.

## Rollback funcional
El frontend puede volver a RPC v072 para perfiles heredados y ocultar Profesional/Espectador. Las estructuras v196 son aditivas; no se borran datos.
