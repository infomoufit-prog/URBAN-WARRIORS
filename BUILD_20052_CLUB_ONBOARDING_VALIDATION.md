# KOMBAX 20.052 · CLUB ONBOARDING · VALIDACIÓN DE BUILD

Estado: BUILD DE VALIDACIÓN (NO FREEZE FINAL / NO DEPLOY)
Fecha: 2026-08-19
Base: KOMBAX 20.051 · SECURITY UI TRANSVERSAL

## Implementación realizada
- Club aparece como identidad oficial junto a Competidor, Federación y Marca.
- Iconografía Club usa el sistema SVG KOMBAX existente.
- Alta autoservicio de Club con datos públicos, datos privados de verificación y documento acreditativo.
- La aprobación `verified` por Administrador KOMBAX provisiona de forma atómica un tenant real en `public.clubes`.
- El solicitante queda asignado como Dirección/Coordinación del nuevo Club.
- Los triggers existentes generan perfil público, identidad Social, configuración/comunidad/legal, códigos y prefijo de recibos.
- Administración KOMBAX incorpora `+ Crear club` para alta directa con responsable KOMBAX existente.
- `Mis identidades` muestra los Clubes gestionados con Gestionar club, Ver perfil público y Seguridad y acceso.
- La revisión de una solicitud Club muestra estado de Provisionamiento, separado del concepto de servicio/premium.

## Supabase
- Migración aplicada: `kombax_club_onboarding_20052` (archivo local `097_kombax_club_onboarding_20052.sql`).
- Rollback incluido: `097_kombax_club_onboarding_20052_rollback.sql`.
- `kombax_solicitudes_alta.club_id` presente.
- Trigger de provisionamiento presente.
- RPC interna de creación: sin EXECUTE para anon/authenticated.
- RPC Mis Clubes: anon NO / authenticated SÍ; filtra por `auth.uid()` y membresía Dirección/Coordinación activa.
- RPC alta directa Admin: anon NO / authenticated SÍ; exige guard interno `platform_admin`.
- No se creó ningún Club de prueba persistente.

## Prueba transaccional real de provisionamiento
PASS. En una transacción se creó un Club QA temporal y se comprobó:
- tenant `clubes`: OK
- perfil público: OK
- identidad Social: OK
- responsable Dirección + Coordinación: OK
- 2 disciplinas: OK
- prefijo de recibos: OK
Después se ejecutó ROLLBACK y la comprobación posterior devolvió 0 Clubes QA persistentes.

## Tests y build
- `node scripts/test-kombax-20052-club-onboarding.mjs`: PASS
- `npm test`: PASS completo hasta build 20052
- `npm run build`: PASS
- builder: 64 archivos · web = dist = Android
- comparación SHA-256 independiente: web 64 / dist 64 / Android 64; missing 0 / extra 0 / diff 0
- SHA-256 agregado árbol web: `dc11b2cd2a4814f5432ffc6f1bf3388b67d03df4f2c57515a50967cdcf42366f`

## Android
- applicationId: `com.urbanwarriors.app`
- versionCode: 20052
- assets/www: OK
- Firebase: OK
- Firma local: PENDIENTE deliberadamente; `keystore.properties`/JKS no se distribuyen dentro de la build.
- Preflight: 4/5. No generar release definitiva hasta usar la firma local autorizada.

## Secret audit
- service_role literal/token: 0 hallazgos
- private PEM key: 0 hallazgos
- JKS/keystore.properties dentro de la build: 0 hallazgos

## Advisors Supabase
Security Advisor: no está limpio globalmente. Persisten avisos históricos que deben clasificarse antes del freeze final, incluido `auth_leaked_password_protection` desactivado y RPC SECURITY DEFINER deliberadamente expuestas por la arquitectura. Las nuevas funciones 20.052 fueron verificadas con mínimos grants; la función core interna no es ejecutable por anon/authenticated.

Performance Advisor: persisten avisos históricos de FKs sin índice, `auth_rls_initplan`, políticas permisivas múltiples, índices no usados y un índice duplicado histórico. El nuevo índice `idx_kombax_solicitudes_alta_club_v097` aparece como no usado por ser recién creado y no haber tráfico real todavía. No se han aplicado optimizaciones masivas en esta build para evitar alterar comportamiento funcional durante Club Onboarding.

## Pendientes manuales antes de freeze
- Alta real desde navegador con una cuenta de prueba de Club.
- Revisión y Verificar desde una sesión real de Administrador KOMBAX.
- Entrada posterior del nuevo Gestor al Club y edición de logo/portada/perfil público.
- Verificación móvil por red local.
- Auditoría final global de advisors y seguridad de políticas históricas.
- Firma APK/AAB solo en fase release posterior.

No se ha hecho push a GitHub, deploy Netlify, APK/AAB release ni publicación Google Play.
