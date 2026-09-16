# PLAN_IMPLEMENTACION_R29 · MANAGED PROFILE HUBS

## Base
R28 PROFILE & CAPABILITY FOUNDATION cerrada con regresión completa, test R28 13/13, build y paridad web=dist=Android.

## Objetivo
Crear entornos diferenciados para perfiles directos sin duplicar KOMBAX ni convertir Mi Federación/Mi actividad en variantes de Mi Club.

## Alcance
- RPC de workspace gestionado por subject, con `auth.uid()` + comprobación de gestión.
- `Mi Federación`, `Mi Marca`, `Mi actividad`, `Mi Competidor`, `Mi perfil` Espectador.
- Navegación derivada de capacidades.
- Resumen de gestores del perfil sin exponer credenciales.
- Federación declara explícitamente `private_club_access=false`; afiliación nunca concede lectura privada del tenant Club.
- Botón de apertura del entorno desde Mis identidades.
- Cambio de identidad/caches ya aislado por R28.

## No alcance
- Clientes/sesiones/representación profesional (R30).
- Finanzas Profesionales (R31).
- Nueva relación federativa privada con Club.

## Backend
Nueva RPC `app_kombax_managed_profile_hub_v197(uuid)` sin tabla nueva. Devuelve solo datos del perfil gestionable, capacidades efectivas, especialidad Profesional, módulos y roles de gestores. No consulta alumnos, finanzas, documentos privados ni membresías de clubes afiliados.

## Seguridad
- `SECURITY DEFINER`, `search_path=public,auth`.
- sesión obligatoria.
- `app_kombax_puede_gestionar_perfil_v070(...,'read')` obligatoria.
- `REVOKE ALL` public/anon y `GRANT EXECUTE` authenticated.
- ningún UUID de club se usa como autorización.

## Frontend
- `managed-profile-hub.js` común.
- wrappers: `federation-hub.js`, `brand-hub.js`, `professional-hub.js`, `competitor-hub.js`, `spectator-hub.js`.
- repositorio `workspace(profileId)`.
- Gateway añade “Abrir Mi …” a cada identidad directa.

## QA gate
- los cinco hubs existen y tienen títulos distintos.
- Federación muestra frontera de privacidad Club.
- Espectador no muestra creación/publicación.
- Profesional se compone por capabilities.
- Social/Showcase siguen únicos/globales.
- test completo + build + parity + Android preflight.

## Rollback
Revocar/retirar la RPC v197 y ocultar el botón `data-kx-profile-open-hub`; los perfiles R28 permanecen íntegros.
