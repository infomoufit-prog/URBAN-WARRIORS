# KOMBAX 20.101 R43 · Plan de implementación

## Alcance
Reducir la exposición y consumo de KOMBAX Assist / KOMBAX Migrations para que sean herramientas organizativas prioritarias. Se parte exclusivamente de R42.

## Política R43
- Club: visible para dirección, coordinación, secretaría y economía.
- Federación: visible en el hub de Federación.
- Marca: no activada en R43; queda para un entitlement específico posterior.
- Alumno, familia, monitor, comunicación, competidor, profesional y espectador: sin acceso protagonista a Assist/Migrations.

## Riesgos
- Que ocultar solo la UI deje rutas profundas o llamadas directas capaces de consumir IA.
- Que una restricción excesiva rompa soporte general por correo.
- Regresiones en navegación, hubs de perfiles, build web/dist/Android o migraciones previas.

## Archivos / migraciones
- web/js/app.js
- web/js/modules/managed-profile-hub.js
- web/js/modules/customer-operations.js
- supabase/migrations/235_kombax_org_assist_priority_r43.sql
- scripts/test-kombax-20101-r43-org-assist-priority.mjs
- package.json

## QA
- Comprobar navegación por rol.
- Comprobar banners contextuales.
- Comprobar hubs directos Federación vs perfiles personales.
- Comprobar guardrail SQL previo a reserva de turno IA y subida de archivos.
- Regresión R42 completa.
- Build y paridad web/dist/Android.

## Criterio de cierre
R43 solo puede declararse candidata cuando los perfiles personales no muestran Assist/Migrations como opción principal, los intentos directos no pueden reservar IA y la regresión R42 permanece en PASS.
