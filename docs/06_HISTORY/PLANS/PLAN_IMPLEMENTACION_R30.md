# KOMBAX 20.101 R30 · PLAN DE IMPLEMENTACIÓN
## PROFESSIONAL RELATIONS & BASIC OPERATIONS

Base: R29 MANAGED PROFILE HUBS cerrada por regresión y build/paridad.

## Objetivo
Implementar operaciones básicas reales por especialidad Profesional y relaciones consentidas Manager↔Competidor, sin convertir Profesional en Club, sin datos clínicos y sin ampliar privilegios por identidad bruta.

## Alcance
- Capabilities derivadas de especialidad principal/secundaria y estado de verificación.
- Entrenador: clientes propios y sesiones operativas no clínicas.
- Manager: delegaciones solicitadas, aceptadas, rechazadas/revocadas/expirables y permisos mínimos.
- Médico/Sanitario: credenciales y disponibilidad; asignaciones a Events, sin expediente sanitario.
- Árbitro/Juez: credenciales, disponibilidad y asignaciones limitadas a Events.
- Promotor/Organizador: capacidades Events ya existentes, sin ticketing/cobro.
- Workspace/RPC seguro para Profesional y para Competidor receptor de delegación.
- Auditoría de mutaciones sensibles.
- UI Profesional/Competidor integrada en los hubs R29.

## Fuera de alcance
- Salud clínica, lesiones, historia médica, consentimientos sanitarios.
- Contratos legales automatizados.
- Finanzas Profesionales (R31).
- Procesamiento de pagos/ticketing.
- Acceso del Profesional a alumnos/finanzas/documentos privados de un Club por ser Profesional.

## Backend / migración prevista
Migración 200 `kombax_professional_relations_operations_20101_r30.sql` (número local consecutivo; backend usa su propia versión temporal).
Entidades nuevas aisladas por `professional_profile_id`:
- kombax_professional_clients_v198
- kombax_professional_sessions_v198
- kombax_professional_credentials_v198
- kombax_professional_availability_v198
- kombax_professional_delegations_v198
- kombax_professional_assignments_v198
- kombax_professional_audit_v198
- kombax_professional_specialty_capabilities_v198

RPC:
- app_kombax_professional_has_specialty_v198
- app_kombax_profile_capabilities_v196 (extensión aditiva por specialty)
- app_kombax_professional_workspace_v198
- app_kombax_professional_mutate_v198

## Seguridad / RLS
- RLS en todas las tablas.
- Ownership/gestión del perfil comprobado backend.
- Aceptar/rechazar una delegación solo desde el Competidor objetivo o administración global auditada.
- Revocación por cualquiera de las partes autorizadas.
- Sin permisos por relación mientras estado != accepted o haya expirado/revocado.
- SECURITY DEFINER con search_path fijo, auth.uid y subject verificados.
- Sin credenciales de cuenta compartidas.
- Tablas internas sin grants directos de escritura a authenticated; mutación vía RPC.

## Frontend
- `professional-operations.js` como módulo único de operaciones del perfil.
- Entrenador: alta/listado de clientes y sesiones.
- Manager: solicitar representación por identificador de Perfil Competidor y ver estado/permisos.
- Médico/Árbitro: credenciales/disponibilidad/asignaciones de solo lectura/estado.
- Promotor: acceso guiado a Events por capabilities.
- Competidor: bandeja de solicitudes de representación con aceptar/rechazar/revocar.
- Repositorios por RPC, sin SELECT directo a tablas privadas.

## Riesgos y mitigación
1. Escalada Manager→Competidor: aceptación obligatoria y permissions allowlist.
2. Subtipo usado como autorización total: specialty solo añade elegibilidad/capabilities previstas; las mutaciones revalidan ownership y contexto.
3. Datos clínicos accidentales: esquema sin campos de salud/lesiones y copy no clínico.
4. Contaminación entre perfiles: toda consulta filtra subject y se invalida al cambiar identidad.
5. Events sobreadministrado: asignaciones no conceden administración global.

## QA
- Test estático R30 de contratos.
- Test de grants/RLS y funciones live.
- Regresión completa npm test.
- Build y paridad web/dist/Android.
- Android preflight.
- Advisors tras migración.

## Gate de cierre
R30 solo cierra si:
- Entrenador solo gestiona sus clientes/sesiones.
- Manager no tiene acceso sin aceptación y la revocación corta la delegación.
- Médico no dispone de ningún dominio clínico.
- Árbitro/Médico tienen asignaciones limitadas.
- Promotor reutiliza Events por capability.
- RLS/RPC/grants no introducen bypass conocido.
- R29 y toda regresión histórica siguen pasando.

## Advisor hardening after implementation
Performance Advisor identified four `auth_rls_initplan` warnings introduced by R30 on INSERT defense-in-depth policies. Migration `201_kombax_professional_relations_r30_advisor_hardening.sql` replaces direct `auth.uid()` comparisons with `(select auth.uid())`. INFO-only unindexed foreign-key notices on audit/actor columns are documented for R32 review and are not indexed blindly without a demonstrated query path.
