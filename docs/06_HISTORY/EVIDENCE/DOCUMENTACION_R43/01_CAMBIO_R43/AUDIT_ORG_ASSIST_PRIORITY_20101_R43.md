# KOMBAX 20.101 R43 — Auditoría de prioridad organizativa Assist/Migrations

## Base
R43 deriva exclusivamente de la candidata R42. R42 no se modifica.

## Alcance implementado
- KOMBAX Assist y KOMBAX Migrations dejan de aparecer como navegación prioritaria para identidades personales.
- Club: acceso limitado a roles organizativos `direccion`, `coordinacion`, `secretaria`, `economia`.
- Federación: acceso mantenido para el propietario del perfil directo activo de tipo `federacion`.
- Alumno, familia, monitor, comunicación, competidor/profesional y demás identidades personales: sin acceso organizativo.
- Marca: deliberadamente NO habilitada en R43. Queda como decisión futura con entitlement propio si se justifica.
- Backend: el guardrail se evalúa antes de reservar allowance/turno de IA o registrar archivos de migración, evitando consumo evitable por perfiles no autorizados.

## Evidencia automática
- Test focal R43: 18/18 PASS.
- Regresión R42: 24/24 PASS.
- Regresión R40: 74/74 PASS dentro de `npm test`.
- `npm test`: EXIT 0.
- Build: PASS, 189 archivos.
- Paridad: web=dist=Android, 0 diferencias de hash.
- Escaneo de secretos runtime: 888 archivos, 0 hallazgos.
- Android preflight: 4/5; único pendiente: `android/keystore.properties` local. No se incluye secreto de firma en el ZIP.

## Backend vivo
La migración `kombax_org_assist_priority_r43` fue aplicada al proyecto Supabase principal `poggsobhtutbuagjiydc` durante esta fase.

La consulta posterior de verificación viva de ACL/orden de funciones fue bloqueada por la herramienta al no poder determinar el estado de seguridad de la solicitud. Los advisors de seguridad/rendimiento tampoco quedaron capturados con evidencia reproducible en el cierre. Por tanto, NO se declaran como verificados.

## Estado
Candidata técnica R43 lista para PRE-QA/QA funcional. No equivale a autorización para introducir datos personales reales ni a aprobación de ciberseguridad.
