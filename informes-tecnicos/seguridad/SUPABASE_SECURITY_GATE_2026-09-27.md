# KOMBAX — Fase 1: seguridad Supabase

**Corte:** 27/09/2026. **Proyecto real:** `poggsobhtutbuagjiydc`, `eu-west-1`. **Base acumulativa de referencia:** R104.1/20156. Esta auditoría es incremental sobre `outputs/KOMBAX_PILOT_RELEASE_GATE_2026-10-01.md`; ningún resultado anterior se presenta como prueba nueva. No se modificaron RLS, permisos, Auth ni datos de usuarios en esta fase.

## Estado general

El conector informa `ACTIVE_HEALTHY` y PostgreSQL `17.6.1.155`. Se observaron 31 Edge Functions activas: 21 con `verify_jwt=true` y 10 con `verify_jwt=false`. Hay 18 buckets de Storage; dos son públicos por diseño (`club-public-media`, `kombax-public-media`). Las 51 políticas de `storage.objects` requieren una matriz de operaciones HTTP antes de certificar ownership y rutas privadas.

En la ventana reciente de 24 horas se observaron 1.468 eventos `function_edge_logs`. El único HTTP >=400 agrupado por función fue un 409 del primer intento de verificación de backup de esta auditoría. La repetición pasó con 102/102 artefactos. Estos logs no sustituyen alertas operativas ni pruebas de carga.

Se hizo un barrido local de patrones concretos de claves privadas (Stripe `sk_live`/`sk_test`/`rk_live`, OpenAI `sk-proj`, Supabase `sb_secret`, secretos webhook y bloques de claves privadas) sin coincidencias en el checkout. Es una comprobación parcial de patrones, no una auditoría exhaustiva de secretos ni de variables del despliegue.

## Security Advisors y prioridad

| Hallazgo | Cantidad | Prioridad | Interpretación |
|---|---:|---|---|
| RLS habilitada sin política | 201 | P3 informativo | Tablas cerradas por defecto; no implica exposición. Verificar nuevos grants y RPC que las usan. |
| `SECURITY DEFINER` ejecutable por `anon` | 51 | P1 de revisión dirigida | Requiere inspección de autorización por función y pruebas HTTP con IDs ajenos. No revocar masivamente. |
| `SECURITY DEFINER` ejecutable por `authenticated` | 554 | P1 de revisión dirigida | Superficie amplia. Se revisó la cadena de `procesar_cargos_recurrentes`: la función intermedia exige `service_role` o rol `direccion/economia` del club antes de procesar. Este ejemplo no certifica las demás funciones. |
| Protección de contraseñas filtradas desactivada | 1 | P1 | La [documentación de Supabase](https://supabase.com/docs/guides/auth/password-security) la reserva a Pro o superior; la organización consultada está en Free. No se contrató ni cambió el plan. |

## RLS y Data API

`public`: 205/205 tablas ordinarias con RLS. `kombax_ai_ops`: 17/17. `kombax_commercial`: 22/22. `kombax_compliance`: 17/17. `kombax_customer_ops`: 11/11. `kombax_payments`: 27/27. `kombax_inventory`: 1/1. `kombax_marketplace`: 1/8; las siete tablas sin RLS no conceden SELECT/INSERT/UPDATE/DELETE a `anon` ni `authenticated`. Un barrido de tablas de aplicación sin RLS y con permisos directos a dichos roles devolvió cero filas. Esto no prueba que todos los RPC que acceden a ellas sean seguros.

Storage contiene 24 informes financieros y un documento de miembro bajo la ruta del Club A, además de un documento de verificación del propietario del Club A. Una aserción SQL con el monitor exclusivo del Club B devolvió cero objetos visibles en esas tres rutas privadas. Quedan sin probar las URLs firmadas y las operaciones HTTP de subir, reemplazar y borrar.

Las 39 políticas UPDATE de `public` tienen `WITH CHECK` explícito; las 39 tablas correspondientes disponen de política SELECT o ALL. Las 911 funciones `SECURITY DEFINER` de `public` tienen `search_path` fijado. Los advisors marcan 51 ejecutables por `anon` y 554 por `authenticated`; sigue pendiente la revisión funcional completa y las pruebas con tokens reales. La auditoría anterior solo probó RLS/RPC dirigidos con dos clubes y transacciones revertidas.

Prueba adicional con rol SQL `authenticated` y usuario monitor exclusivo del Club B: acceso por `club_id` a 10 socios, 17 cuotas, 12 pagos y 5 miembros del Club A devolvió cero en las cuatro tablas. Los cuatro grupos activos del Club A sí son visibles porque `grupos_publico_registro` publica grupos activos de clubes activos incluso para `anon`; no se clasifican como fuga privada. Al desactivar temporalmente un grupo dentro de una transacción revertida, el monitor del Club B dejó de verlo. Esta prueba precisa el límite entre catálogo de inscripción público y grupo interno inactivo; no sustituye sesiones Auth ni llamadas HTTP.

### Hallazgo corregido: stock de borradores Showcase

La RPC pública `app_showcase_listing_details_r628(uuid[])` era `SECURITY DEFINER` y devolvía `stock_status` para cualquier ID, incluso con `estado='borrador'`. Se reprodujo con `anon` cambiando temporalmente un producto publicado a borrador dentro de una transacción revertida; la consulta devolvió una fila (`DRAFT_STOCK_LEAK_CONFIRMED`). El producto quedó publicado tras el rollback.

La migración `290_kombax_showcase_listing_visibility_pilot.sql` conserva firma y columnas, pero permite consultar solamente productos publicados de proveedor publicado o borradores del gestor autorizado del proveedor. Se aplicó en Supabase. Pruebas posteriores, todas revertidas: `anon` ve producto publicado; `anon` no ve borrador; dirección del Club A ve su borrador; monitor exclusivo del Club B no ve el borrador del Club A. Las cuatro aserciones pasaron. Clasificación: **P1 corregido** por exposición de información comercial privada mediante Data API. No se cambiaron pedidos ni stock.

La revisión de la RPC relacionada `app_showcase_commerce_details_v259(uuid[])` detectó el mismo patrón con mayor detalle: un usuario `authenticated` podía consultar stock exacto y variantes de un borrador ajeno por ID. La migración `291_kombax_showcase_commerce_details_visibility_pilot.sql` aplica el mismo predicado de publicación o gestión autorizada, sin cambiar firma ni columnas. Tras aplicarla, las aserciones transaccionales comprobaron: producto público visible para un miembro de otro club, borrador visible para dirección propia y borrador oculto para el monitor del otro club. **P1 corregido.** Queda pendiente una matriz HTTP con sesiones reales.

Otra RPC autenticada, `app_showcase_product_compliance_r630(uuid)`, devolvía datos de vendedor, producto y moderación de un borrador ajeno. Se reprodujo con el monitor del Club B contra un producto del Club A, dentro de una transacción revertida. La migración `292_kombax_showcase_compliance_visibility_pilot.sql` conserva el contrato y permite acceso al producto publicado, al gestor del proveedor o al administrador de plataforma. Pasaron tres aserciones: publicación visible al miembro, borrador visible al gestor y borrador ajeno denegado. El producto de prueba siguió `publicado` tras el rollback. **P1 corregido.** La RPC existía en el proyecto real aunque no se encontró una definición anterior en el ZIP R104.1; la migración 292 documenta ahora su definición vigente y el parche.

## Auth y gate administrativo

Hay **0 factores MFA verificados** en `auth.mfa_factors`. `owner_mfa_required=false` y `pilot_security_enabled=false`. El propietario indicó expresamente que durante el piloto se usará la cuenta Owner con contraseña convencional y que TOTP se abordará después del piloto. No se activará AAL2 en esta fase. El riesgo de compromiso de una cuenta administrativa con un solo factor permanece abierto y debe evaluarse con controles compensatorios verificables; la preferencia del propietario no equivale a una prueba de seguridad. Los siete controles `kombax_pilot_readiness_v117` continúan `false`: `smtp`, `legal_controller`, `owner_mfa`, `backup_export`, `restore_drill`, `monitoring`, `incident_runbook`. Registro, recuperación, revocación y rate limiting precisan prueba de extremo a extremo.

La ruta administrativa `app_kombax_platform_admin_password_session_v139` comprueba un login con contraseña reciente (hasta 600 segundos), exige admin activo y `session_id` Auth. La sesión privilegiada dura 30 minutos, termina sesiones anteriores del mismo Owner y escribe `kombax_platform_privileged_audit`. Estas barreras existen en SQL; no se ha completado aún la prueba interactiva de inicio, expiración y revocación. Reducen exposición de una sesión normal, pero no sustituyen TOTP si se compromete la contraseña.

La ruta de verificación de competidores recibió una prueba negativa adicional. `authenticated` no tiene permisos directos INSERT/UPDATE/DELETE sobre `perfiles_kombax_directos`, `kombax_verificacion_documentos`, `kombax_verificacion_eventos` ni `kombax_verificadores_globales_v117`; las columnas de estado de verificación tampoco son actualizables directamente. La RPC antigua `app_kombax_perfil_mutate_v043` no es ejecutable por `anon` ni `authenticated`. La vigente `app_kombax_perfil_mutate_v072` exige `app_kombax_es_platform_admin_v055()` para `kombax.application.review`; `app_kombax_verificador_set_v117` exige el mismo control. Con el UID del monitor exclusivo del Club B y un `session_id` de prueba, ambas llamadas rechazaron la operación con `PLATFORM_ADMIN_REQUIRED`. No se alteraron perfiles ni verificadores. Es evidencia SQL dirigida de que ese usuario no puede autoverificarse por estas rutas; falta repetirlo por HTTP con sesión Auth real y revisar otras rutas de verificación.

En Showcase se probó además la lectura de pedidos del proveedor del Club A desde el usuario monitor del Club B: `kombax_payments.can_manage_provider` devolvió `false` y `app_showcase_seller_orders_v259` rechazó con `SELLER_ACCESS_DENIED`. La búsqueda pública `app_kombax_showcase_list_v054` filtra producto y proveedor publicados. La RPC pública de reseñas `app_kombax_showcase_reviews_r73` filtra producto publicado, pero no exige proveedor publicado; hoy los cinco productos examinados tienen cero reseñas. Se registra como revisión P2 del contrato de visibilidad antes de usar reseñas reales, sin alterar su comportamiento en este parche.

Los 13 registros `auth_logs` de la ventana reciente solo permiten constatar cinco `token_revoked` HTTP 200, un `token_refreshed` HTTP 200 y un `logout` HTTP 204; no son una prueba de registro, recuperación o login nuevo. El recuento actual es cero sesiones privilegiadas activas, cinco históricas.

## Backup y recuperación

La copia `20077-2026-09-27T07-59-52-702Z` quedó verificada: 3 archivos DB, 99 objetos Storage, 84.186.880 bytes, 102/102 artefactos y 0 fallos en la comprobación final. Está en un bucket privado **del mismo proyecto**. Aún no existe evidencia de exportación externa ni de restauración aislada; no se ha marcado `backup_export` ni `restore_drill` como verificado. Los tokens temporales usados para exportar y verificar se desactivaron.

El procedimiento de incidentes histórico existe, pero describía un piloto de dos clubes y evidencia del 24/08. Se documentó el alcance actual de cuatro clubes en [`../procedimientos/INCIDENT_RESPONSE_PILOT_2026.md`](../procedimientos/INCIDENT_RESPONSE_PILOT_2026.md). No se marcó `incident_runbook` como verificado: faltan simulacro, responsable suplente y prueba de entrega de avisos.

## Hallazgos y siguiente fase

| ID | Prioridad | Estado | Evidencia pendiente |
|---|---|---|---|
| S1 | P1 | Diferido por propietario | Owner con contraseña convencional durante piloto. No activar TOTP/AAL2; verificar controles compensatorios, documentar aceptación de riesgo y reevaluar después del 15/11. |
| S2 | P1 | Abierto | Matriz HTTP REST/RPC/Storage con cuatro cuentas de clubes distintos, incluidos menores, invitaciones, finanzas, productos y verificaciones. |
| S3 | P1 | Abierto | Copia fuera del proyecto y restore drill aislado con RPO/RTO. |
| S4 | P1 | Abierto | Atestar controles SMTP, responsable legal, monitoring y runbook con pruebas fechadas. |
| S5 | P1 | Abierto | Decidir protección contra contraseñas filtradas: plan Pro autorizado o controles compensatorios comprobados. |
| S6 | P1 | En revisión | Inventario de RPC `SECURITY DEFINER` sensibles y comprobación de autorización por ruta; dos fugas Showcase se corrigieron en S7/S8, pero la revisión del resto sigue abierta. |
| S7 | P1 | Corregido | RPC de detalles Showcase filtrada por publicación o gestor autorizado; reproducción previa y cuatro aserciones posteriores registradas arriba. |
| S8 | P1 | Corregido | RPC de comercio Showcase filtrada por el mismo criterio; tres aserciones posteriores pasaron. |
| S9 | P1 | Corregido | RPC de cumplimiento Showcase protegida para borradores; reproducción previa y tres aserciones posteriores pasaron. |

**Fase 1: incompleta. Veredicto provisional: NO-GO técnico.** No se encontraron P0 confirmados en las rutas revisadas, pero faltan pruebas de aislamiento y recuperación exigidas para cuatro clubes reales. Se continúa únicamente con los bloqueos del release gate; el Owner de escala y el roadmap pospiloto permanecen aplazados.
