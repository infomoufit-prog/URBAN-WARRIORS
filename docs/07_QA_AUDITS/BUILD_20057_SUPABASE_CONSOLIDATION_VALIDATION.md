# KOMBAX 20.057 · SUPABASE CONSOLIDATION — VALIDACIÓN

Fecha de consolidación: 2026-08-19  
Proyecto Supabase auditado: `poggsobhtutbuagjiydc`  
Base de código: `KOMBAX_Urban_Warriors_RC13_build_20057_SUPABASE_CONSOLIDATION`

## Estado

**CANDIDATA TÉCNICA DE SEED / CONSOLIDACIÓN. NO FREEZE FINAL TODAVÍA.**

La auditoría y reparación técnica no ha encontrado un bloqueo funcional nuevo después de las correcciones. La suite completa, build, sincronización, RLS real por roles, Storage privado, superficie RPC y aislamiento multiclub transaccional son conformes.

Permanecen fuera del cierre automático:

1. **Supabase Auth · Leaked Password Protection**: el Security Advisor sigue indicando que está desactivada. Es una configuración de Auth del Dashboard, disponible en Supabase Pro o superior; no es una migración SQL y no existe una acción conectada en este entorno para modificarla de forma segura.
2. **E2E manual de navegador/móvil**: debe hacerse sobre esta 20.057 antes de declarar freeze final.
3. **Firma Android local**: preflight 4/5 porque `android/keystore.properties` y el JKS privado no se empaquetan deliberadamente.

## Estrategia de auditoría

No se intentó “poner en verde” los Advisors de Supabase a costa de cambiar la arquitectura. Cada aviso se clasificó como:

- hallazgo funcional o de seguridad real;
- optimización de rendimiento demostrable;
- patrón deliberado de arquitectura;
- INFO sin beneficio suficiente para justificar una modificación.

Todas las intervenciones de esquema se hicieron mediante migraciones versionadas y con rollback local correspondiente.

## Migraciones nuevas aplicadas en producción

### 100 · `kombax_supabase_consolidation_20057`

Versión viva: `20260819155319`

Cambios principales:

- cierre de ejecución directa por clientes de cinco RPC superseded;
- estabilización de Auth en RLS con `(select auth.uid())` / `(select auth.jwt())`;
- estrechamiento de policies históricas `TO PUBLIC` a `authenticated` cuando `anon` no tenía privilegio de tabla;
- eliminación de índice material duplicado;
- primeros índices FK de rutas de alto crecimiento.

RPC superseded cerradas al cliente:

- `app_kombax_social_mutate_v083(text,jsonb,uuid)`;
- `app_kombax_identity_mutate_v065(text,jsonb,uuid)`;
- `app_kombax_social_feed_v083(timestamptz,uuid,integer)`;
- `app_kombax_social_media_v053(uuid)`;
- `app_kombax_perfil_publico_v083(uuid)`.

Hallazgo real corregido: las dos primeras podían permitir acceso directo a lógica anterior y evitar reglas canónicas posteriores, en especial la protección Social v099 de 3 publicaciones/día respaldada por auditoría y la continuidad de identidad v094.

Rollback: `supabase/rollbacks/100_kombax_supabase_consolidation_20057_rollback.sql`.

### 101 · `kombax_rls_policy_consolidation_20057`

Versión viva: `20260819160145`

Se consolidaron policies permisivas solapadas sin eliminar ninguna rama de autorización. Las policies `ALL` de gestión se separaron por INSERT/UPDATE/DELETE y la lectura quedó expresada en una sola policy con el OR lógico exacto de las condiciones previas.

Casos especiales tratados individualmente: notificaciones, accesos a clase, preinscripciones, perfiles y rutas públicas de registro.

Verificación directa del catálogo después de aplicar:

- grupos duplicados de policies permisivas para `authenticated` por tabla/acción: **0**;
- `auth_rls_initplan`: eliminado del Performance Advisor;
- `multiple_permissive_policies`: eliminado del Performance Advisor.

Rollback: `supabase/rollbacks/101_kombax_rls_policy_consolidation_20057_rollback.sql`.

### 102 · `kombax_relational_fk_indexes_20057`

Versión viva: `20260819160556`

Se añadieron **62 índices** para relaciones funcionales/estructurales todavía sin cobertura: socios, tarifas, consentimientos, material, competición, Social, verificación, planes, moderación, recibos, documentos y otras rutas de negocio.

Verificación directa del catálogo después de aplicar:

- FK estructurales/funcionales sin cobertura: **0**;
- FK sin índice restantes: **91**, todas clasificadas como referencias de actor/auditoría (`creado_por`, `revisado_por`, `moderado_por`, `archivado_por`, etc.).

Estas 91 no se indexan por defecto porque no forman parte de rutas funcionales de búsqueda/relación y añadir índices indiscriminadamente aumentaría coste de escritura y almacenamiento.

Rollback: `supabase/rollbacks/102_kombax_relational_fk_indexes_20057_rollback.sql`.

## Security Advisor — estado y clasificación final

### `rls_enabled_no_policy` — INFO deliberado

Se verificaron **47 tablas** con RLS habilitado y sin policy. Para esas 47 tablas:

- grants directos anon SELECT/INSERT/UPDATE/DELETE: **0**;
- grants directos authenticated SELECT/INSERT/UPDATE/DELETE: **0**.

Son tablas **deny-by-default** que se alcanzan mediante RPC controladas. Crear policies vacías o permisivas solo para silenciar el linter reduciría seguridad y contradice la arquitectura.

### `anon_security_definer_function_executable` — WARN intencional

Las cinco fachadas anónimas revisadas son endpoints públicos reales:

- búsqueda pública de Clubes;
- validación de código de acceso con rate limiting;
- catálogo público de alta;
- categorías de Showcase;
- listado público de Showcase.

Se revisó su finalidad y `search_path`. No se revocan porque hacerlo rompería funcionalidades públicas intencionadas.

### `authenticated_security_definer_function_executable` — WARN arquitectónico

La API KOMBAX usa tablas cerradas y fachadas/helpers `SECURITY DEFINER` que validan al actor dentro de la función o sirven de helper para RLS/Storage. Revocar EXECUTE globalmente rompería el modelo de autorización.

La auditoría cerró las fachadas superseded que sí eran innecesarias y conservó las RPC actuales/helpers requeridos.

### `auth_leaked_password_protection` — WARN real pendiente

Sigue desactivada. La documentación actual de Supabase indica que se configura en Auth settings y está disponible en Pro o superior. Este punto **impide declarar un Security Advisor completamente resuelto** hasta que se active o se acepte explícitamente el riesgo.

## Performance Advisor — estado final

Eliminados por las migraciones 100–102:

- `auth_rls_initplan`;
- `multiple_permissive_policies`;
- índice duplicado de `material_pedidos`;
- todas las FK funcionales/estructurales sin índice detectadas por la auditoría propia.

Residual deliberado:

- `unindexed_foreign_keys` INFO sobre referencias de actor/auditoría;
- `unused_index` INFO, incluyendo índices nuevos y otros con poco tráfico en una base todavía pequeña.

No se eliminan índices por el simple hecho de que aún no tengan uso estadístico. Esa decisión debe revisarse con carga real y `pg_stat_user_indexes` después del piloto.

## Superficie RPC frontend ↔ Supabase vivo

Se extrajeron las llamadas RPC runtime del frontend 20.057 y se cruzaron contra `pg_proc` y privilegios reales.

Resultado:

- RPC activas nombradas por runtime: **76**;
- inexistentes: **0**;
- cerradas por error a todos los roles cliente: **0**;
- `SECURITY DEFINER` activas sin `search_path` fijado: **0**.

Las referencias legacy encontradas en el barrido bruto y cerradas al cliente estaban únicamente en comentarios de compatibilidad/regresión, no en llamadas runtime.

## Smoke tests RLS reales

Las pruebas se ejecutaron como `SET LOCAL ROLE authenticated` con claims de usuarios reales existentes y sin persistir cambios de aplicación.

### Dirección

- `auth.uid()` resuelve al actor correcto;
- perfil propio visible: 1;
- miembro de Club: true;
- miembros visibles: 3;
- socios visibles: 2;
- grupos visibles: 3;
- sesiones visibles: 101;
- notificaciones visibles: 95;
- configuración visible: 9.

### Alumno

- perfil propio visible: 1;
- miembro de Club: true;
- miembros visibles: 1;
- socios visibles: 1;
- grupos visibles: 3 según reglas funcionales de grupos;
- sesiones visibles: 77 según permisos/visibilidad;
- notificaciones visibles: 25;
- configuración visible: 9 según política de configuración de miembro.

### Privacidad alumno ↔ alumno

Un Alumno A consultando específicamente a Alumno B obtuvo:

- perfil de B: **0**;
- socio de B: **0**.

Dirección del mismo Club obtuvo:

- perfil de B: **1**;
- socio de B: **1**.

## Smoke tests RPC reales

Como Dirección y Alumno autenticados:

- `app_runtime_contract_v160`: OK;
- `app_notificaciones_centro_v037`: OK;
- `app_kombax_social_feed_v085`: OK.

Selector multiclub:

- Dirección: 1 Club real gestionable;
- Alumno: 0 Clubes gestionables, conforme al contrato.

## Storage privado — prueba real

Se revisaron las policies de:

- `profile-media`;
- `member-documents`;
- `justificantes-pago`;
- `kombax-restricted-media`;
- `kombax-verification-docs`.

Con objetos privados existentes:

- alumno no titular → documento ajeno: **0**;
- alumno no titular → justificante ajeno: **0**;
- Dirección → mismo documento: **1**;
- Dirección → mismo justificante: **1**;
- fotos `profile-media` del mismo Club → visibles a miembros conforme a diseño.

No se descargó, borró ni modificó ningún objeto durante esta prueba.

## Aislamiento multiclub live con ROLLBACK

Como solo existe un Club real, se creó un segundo Club QA usando **el provisionador canónico `app_kombax_create_club_core_v097`** dentro de una transacción única.

Resultado durante la transacción:

- Alumno del Club original → miembros del Club QA: **0**;
- Alumno del Club original → configuración privada del Club QA: **0**;
- Dirección asignada al Club QA → miembros: **1**;
- Dirección asignada al Club QA → configuración: **1**;
- selector Dirección → 2 Clubes mientras existía el tenant QA.

Se ejecutó `ROLLBACK` y después se verificó:

- Clubes QA persistidos: **0**.

## Validación local 20.057

### Tests

`npm test` → **PASS**

Incluye toda la regresión histórica de producto y las pruebas nuevas:

- `test-kombax-20057-supabase-consolidation.mjs`;
- `test-kombax-20057-rls-policy-consolidation.mjs`;
- `test-kombax-20057-relational-fk-indexes.mjs`.

### Build

`npm run build` → **PASS**

El build vuelve a ejecutar `npm test` y termina con:

`OK build 65 archivos · web = dist = Android`

### Comparación independiente

- web: 65 archivos;
- dist: 65 archivos;
- Android `assets/www`: 65 archivos;
- faltantes: 0;
- extras: 0;
- diferencias SHA-256: 0.

SHA-256 agregado del árbol web:

`856388a85c37bc638cab7e3f25f1275bedea744bb1c583e1ca4252a4faec3c6a`

### Secret audit

- JKS/keystore/P12/PFX privados empaquetados: **0**;
- `android/keystore.properties` privado: **0**;
- valores `sb_secret_`: **0**;
- bloques de clave privada: **0**;
- asignaciones literales de `SUPABASE_SERVICE_ROLE_KEY`: **0**.

Las menciones textuales a `service_role` en SQL/tests son nombres de rol y contratos de permisos, no secretos.

### Android preflight

- applicationId `com.urbanwarriors.app`: PASS;
- versionCode 20057: PASS;
- `assets/www`: PASS;
- Firebase: PASS;
- firma local: PENDIENTE deliberado.

Resultado: **4/5**. Exit 2 por ausencia intencional de material de firma privado.

## Conclusión técnica

20.057 es una **base de consolidación técnicamente coherente y reproducible**. Los hallazgos funcionales reales detectados en Supabase han sido corregidos sin ampliar permisos ni romper las fachadas actuales. Las advertencias residuales están clasificadas y justificadas, no ignoradas.

No se declara FREEZE FINAL todavía. Para ello faltan:

1. activar Supabase Auth Leaked Password Protection si el proyecto está en Pro+;
2. E2E manual local PC/móvil con roles y flujos críticos;
3. después del E2E, generar el freeze final y continuar GitHub/Netlify/Android release.
