# Security Advisor triage · 20.084

- `RLS enabled no policy`: no se corrige en masa. En varias tablas internas de KOMBAX es un diseño deny-by-default y acceso por RPC. Clasificar por tabla.
- `SECURITY DEFINER executable`: no equivale automáticamente a vulnerabilidad. Revisar grants + validaciones internas; reducir RPC heredados cuando el cliente nuevo deje de necesitarlos.
- RPC anon públicas (directorio/catálogo/showcase): mantener solo si su salida está diseñada como pública.
- Protección de contraseñas filtradas: advisor detectó que está desactivada; es blocker del piloto hasta activación.
- Inicio de soporte v114: 20.084 introduce v149, rate limit/MFA enforcement y revoca el bypass authenticated directo.

## Clasificación read-only realizada contra el proyecto activo

Funciones sensibles revisadas:
- `app_kombax_deletion_plan_v119` / `app_kombax_deletion_finalize_v119`: exigen `app_kombax_platform_critical_authorized_v139()` antes de delegar en la implementación previa.
- `app_kombax_moderation_queue_v114` / `app_kombax_moderation_decide_v114`: guard de moderador.
- `app_kombax_metrics_platform_v133`, `app_kombax_platform_entities_v114`, `app_kombax_pilot_readiness_set_v117`, `app_kombax_verificador_set_v117`, `app_kombax_profile_manager_mutate_v070`, `app_kombax_subscription_mutate_v071`: guard de plataforma.
- `app_kombax_contact_mensajes_v106`: comprueba usuario autenticado y pertenencia del hilo a uno de sus actores gestionables. 20.083 añade además los RPC de contexto `club + actor` para impedir mezcla visual/operativa entre workspaces.
- `app_kombax_contactos_v133`: wrapper del inbox global intencional de KOMBAX; el workspace de club 20.083 no debe usarlo.

RPC con `anon EXECUTE` detectados y tratados como superficie pública intencional, pendiente de prueba de minimización de salida:
- búsqueda pública de clubes;
- catálogo público de registro;
- categorías públicas de Showcase;
- listado público de Showcase.

La presencia de `SECURITY DEFINER` sigue siendo una advertencia que exige pruebas de autorización; no se usa como criterio automático de vulnerabilidad.
