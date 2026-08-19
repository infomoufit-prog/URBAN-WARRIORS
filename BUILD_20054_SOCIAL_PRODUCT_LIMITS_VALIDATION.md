# KOMBAX RC13 · build 20.054 · SOCIAL PRODUCT LIMITS

Fecha de validación: 2026-08-19
Estado: **CANDIDATA PARA VALIDACIÓN LOCAL · NO FREEZE FINAL · NO DESPLEGADA**

## Objetivo

Cerrar la experiencia de límites de producto de KOMBAX Social sin reducir la regla vigente de 30 publicaciones activas por identidad y sin sobrecargar los perfiles públicos.

## Implementación funcional

- Regla general actual: 30 publicaciones activas por identidad KOMBAX Social.
- Máximo 3 publicaciones nuevas por día e identidad.
- Máximo 10 vídeos activos por identidad.
- Entrada de KOMBAX Social con tarjeta compacta «Cómo funciona KOMBAX Social».
- Contador real de cupo obtenido desde backend.
- Perfil público: 10 publicaciones iniciales, de más reciente a más antigua.
- Carga progresiva por keyset de otras 10 mediante «Ver publicaciones anteriores».
- Gestión propia separada del perfil público para evitar sobrecarga visual.
- Vista «Gestionar publicaciones»: 10 por bloque, más reciente → más antigua, carga progresiva, acceso «Ir a la más antigua» y marca de la publicación más antigua.
- Al llegar a 30: mensaje de producto legible y acceso a gestionar publicaciones. No se expone el error técnico al usuario como experiencia principal.
- No se elimina automáticamente ninguna publicación: el propietario decide cuál retirar.
- El Álbum permanece independiente del ciclo de vida del post.
- Salvaguarda anti-bypass: borrar una publicación creada hoy no reinicia el cupo diario de 3.

## Supabase · migración 099

Aplicada al proyecto `poggsobhtutbuagjiydc` como `kombax_social_product_limits_20054`.
Versión registrada: `20260819130055`.

Nuevas fachadas:
- `app_kombax_social_cupo_v099(uuid)`
- `app_kombax_social_profile_posts_v099(uuid,timestamptz,uuid,integer)`
- `app_kombax_social_mutate_v099(text,jsonb,uuid)`

Seguridad de ejecución verificada:
- `anon` → sin EXECUTE en las tres RPC v099.
- `authenticated` → EXECUTE únicamente en las fachadas v099 previstas.
- `authenticated` → sin EXECUTE directo en la mutación antigua `app_kombax_social_mutate_v085`.
- `service_role` conserva acceso interno a v085.

El límite diario se calcula desde `kombax_actor_audit` (`social.publish`) para impedir el bypass mediante borrado físico del post del mismo día.

## Tests y build

- `node scripts/test-kombax-20054-social-product-limits.mjs` → PASS.
- `npm test` → PASS completo.
- `npm run build` → PASS.
- Builder: `OK build 65 archivos · web = dist = Android`.

## Igualdad independiente de artefactos

Comparación SHA-256 archivo a archivo:
- web: 65 archivos
- dist: 65 archivos
- Android `assets/www`: 65 archivos
- dist faltantes: 0
- dist extras: 0
- dist diferentes: 0
- Android faltantes: 0
- Android extras: 0
- Android diferentes: 0

SHA-256 agregado del árbol web:
`10ea2662b2bb4b1daef1127a653659742e38730c21210a1af60cbce3b207a156`

## Android preflight

Resultado: **4/5**.

- OK applicationId `com.urbanwarriors.app`
- OK versionCode `20054`
- OK assets web embebidos
- OK Firebase
- PENDIENTE firma local (`android/keystore.properties` / JKS), deliberadamente excluida del paquete

No debe generarse release definitiva hasta incorporar la firma solo en el entorno local de release.

## Escaneo de secretos

Resultado: **0 hallazgos** en el árbol de la candidata para:
- token `service_role`
- claves privadas PEM/OpenSSH
- JKS/keystore/P12/PFX
- `android/keystore.properties`

## Supabase Security Advisor

**No se declara limpio globalmente.**

La migración 099 no ha abierto ejecución anónima de sus RPC. Las nuevas advertencias `authenticated_security_definer_function_executable` de las fachadas v099 son esperadas porque son endpoints autenticados deliberados y se ha verificado su control de autenticación/propiedad.

Persisten advertencias históricas del proyecto que deben clasificarse antes del freeze final, entre ellas:
- múltiples funciones `SECURITY DEFINER` históricas expuestas a `authenticated` y algunas fachadas públicas deliberadas a `anon`;
- tablas con RLS activado y sin policy, en muchos casos usadas como deny-by-default/internas;
- **Leaked Password Protection de Supabase Auth sigue desactivado**, pendiente real de hardening antes del freeze final.

## Supabase Performance Advisor

**No se declara limpio globalmente.**

Persisten advertencias históricas de:
- claves foráneas sin índice de cobertura;
- `auth_rls_initplan`;
- múltiples policies permisivas;
- índices sin uso;
- un índice duplicado histórico en `material_pedidos`.

El índice nuevo `idx_kombax_actor_audit_social_publish_v099` aparece como `unused_index` porque acaba de crearse y todavía no tiene tráfico productivo. No se elimina en esta versión.

Las optimizaciones profundas del feed Social (fast path público, medición con `EXPLAIN (ANALYZE, BUFFERS)`, revisión de índices Social) quedan como bloque separado de **SOCIAL FEED PERFORMANCE HARDENING** para no mezclar cambios de rendimiento globales con esta corrección funcional.

## Pendientes para freeze final

1. Validación manual local en navegador PC.
2. Validación móvil en red local.
3. Prueba UX de reglas/cupo/perfil/gestión/eliminación.
4. Clasificación final de Advisors de Seguridad y Rendimiento.
5. Hardening de leaked-password protection.
6. Auditoría final multiclub/RLS/RPC/Storage/relaciones privadas.
7. Firma Android local y release solo después del freeze.
8. GitHub/Netlify/PWA/APK/AAB/Google Play: **todavía no ejecutados**.

## Conclusión

20.054 queda técnicamente preparada como **candidata para pruebas locales**. No debe considerarse freeze final ni versión desplegada hasta completar las validaciones manuales y la auditoría final pendiente.
