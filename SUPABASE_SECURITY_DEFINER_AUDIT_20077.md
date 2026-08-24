# KOMBAX 20077 · Auditoría SECURITY DEFINER / Supabase Advisors

Fecha de revisión: 24/08/2026  
Proyecto revisado: `poggsobhtutbuagjiydc` (`eu-west-1`)  
Alcance: preparación de piloto controlado de 2 clubes. Esta revisión no autoriza despliegue GitHub/Netlify.

## Resumen

**Resultado: PASS para piloto con deuda de hardening P1/P2, sin bypass P0 demostrado.**

El linter actual de Supabase avisa cuando una función `SECURITY DEFINER` es ejecutable por `anon` o `authenticated`. KOMBAX usa deliberadamente funciones RPC `SECURITY DEFINER` como gateway, mientras las tablas internas sensibles permanecen sin privilegios directos para `anon`/`authenticated`. Por tanto, el aviso no debe resolverse de forma mecánica cambiando todas las funciones a `SECURITY INVOKER` o revocando `EXECUTE`: eso podría romper el aislamiento y el modelo RPC/RLS. La medida correcta es mantener una allowlist explícita y exigir autorización interna y salida mínima en cada RPC.

## 1. RPC públicas `anon` revisadas

Las cuatro RPC señaladas como ejecutables por `anon` fueron inspeccionadas en su definición viva:

- `app_buscar_clubes_kombax_v040(text,integer)` — solo clubes activos/visibles y disciplinas activas; límite máximo 50.
- `app_kombax_registro_catalogo_publico_v087(text)` — catálogo de alta de un club activo: disciplinas/grupos/tarifas activas y textos legales vigentes.
- `app_kombax_showcase_categorias_v042()` — únicamente categorías activas de Showcase.
- `app_kombax_showcase_list_v054(...)` — únicamente elementos `publicado` de marcas `publicada`; límite máximo 24. Con sesión, el único dato privado añadido es el booleano `guardado` del propio usuario.

**Clasificación:** uso público intencional. No se ha observado exposición de tablas administrativas, datos financieros, consentimientos de menores, sesiones Owner ni evidencias de moderación.

## 2. RPC privilegiadas muestreadas

Definiciones vivas revisadas:

- `app_kombax_platform_admin_password_session_v139()` exige `auth.uid()`, `session_id`, administrador activo y método `password` reciente (600 s) antes de abrir sesión privilegiada de 30 min.
- `app_kombax_deletion_plan_v119()` y `app_kombax_deletion_finalize_v119()` exigen `app_kombax_platform_critical_authorized_v139()` antes de entrar en los helpers pre-críticos.
- `app_kombax_platform_mutate_v055(...)` exige `app_kombax_es_platform_admin_v055()` e idempotencia por `request_id` antes de mutar permisos/roles de plataforma.
- `app_kombax_moderation_decide_v114(...)` exige `app_kombax_es_moderador_v041()` antes de aplicar una decisión.
- `app_kombax_monitor_cobro_v057(...)` comprueba nivel financiero y visibilidad del alumno antes de registrar un cobro.
- `app_ciclo_eliminar_definitivo_v133(...)` exige usuario autenticado, confirmación literal y autorización del preview del ciclo antes de eliminar el recurso indicado.

**Clasificación:** no se ha encontrado bypass P0 en la muestra revisada.

## 3. Tablas sensibles sin acceso directo

La comprobación viva de privilegios confirma `false` para SELECT/INSERT/UPDATE/DELETE de `anon`/`authenticated` en la muestra sensible, incluyendo:

- `app_mutation_requests`
- `kombax_message_report_evidence_v122`
- `kombax_metrics_platform_daily_v133`
- `kombax_pilot_readiness_v117`
- `kombax_platform_admin_sessions`
- `kombax_platform_admins`
- `kombax_platform_entity_sessions`
- `kombax_platform_privileged_audit`
- `kombax_social_minor_consents_v121`
- `kombax_social_reportes`
- `kombax_solicitudes_eliminacion`

Los avisos `rls_enabled_no_policy` sobre tablas cerradas no equivalen, por sí solos, a exposición si no existen grants directos y el acceso queda detrás de RPC autorizadas.

## 4. Otros advisors

### Seguridad

- **Leaked password protection:** desactivado. En el plan Free actual, Supabase documenta esta protección como función disponible en planes Pro y superiores. Para un piloto cerrado no se clasifica como P0, pero se recomienda activarla al subir de plan.
- **CAPTCHA / bot protection:** no se ha podido certificar desde las acciones disponibles del proyecto; debe revisarse antes de abrir registros públicos a escala.

### Rendimiento

El advisor devuelve numerosos `INFO` de foreign keys sin índice de cobertura e índices todavía no utilizados. En una base de piloto con muy poco tráfico, "unused index" no demuestra que el índice sea innecesario. No se recomienda borrar ni crear decenas de índices de forma indiscriminada antes del piloto.

## 5. Acciones de hardening posteriores

**P1 antes de apertura pública amplia:**

1. Mantener una allowlist documentada de RPC `SECURITY DEFINER` accesibles por `anon` y `authenticated`.
2. Añadir auditoría automatizada de grants y comprobaciones internas de autorización por cada RPC privilegiada nueva.
3. Activar leaked-password protection cuando el plan lo permita.
4. Certificar CAPTCHA/bot protection y ajustar rate limits al volumen real.

**P2 / rendimiento:** priorizar índices por consultas reales (`pg_stat_statements`, latencia, planes EXPLAIN) y no por el aviso aislado del linter.

## Veredicto de este bloque

**PASS — sin vulnerabilidad P0 demostrada; warnings de arquitectura y hardening registrados como P1/P2.**
