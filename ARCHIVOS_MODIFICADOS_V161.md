# Archivos modificados · Urban Warriors 1.6.0 build 13

Base de comparación: `urban-warriors-v1_6_0-build12-recibos-completa.zip`.

## Nuevos (3)

| Archivo | Contenido |
|---|---|
| `supabase/migrations/017_persistence_recovery_v161.sql` | `app_bootstrap_direccion()`, resellado idempotente de permisos, `app_diagnostico_persistencia_v161()`, `notify pgrst` |
| `scripts/test-sql-migrations-v161.mjs` | Suite que aplica 001→017 sobre PostgreSQL real (PGlite) y prueba una escritura por la puerta. Se omite sin fallar si PGlite no está instalado |
| `INFORME_CORRECCION_PERSISTENCIA_V161.md` | Informe técnico completo |

## Corrección funcional (3)

| Archivo | Cambio |
|---|---|
| `supabase/migrations/015_mutation_governance_v160.sql` | Smoke test: `raise exception` → `raise notice` + `return` cuando aún no hay cuenta de dirección. Única modificación del archivo |
| `web/js/data-store.js` | `login()` no persiste la sesión hasta confirmar contrato y carga; `safeSelect()` registra fallos en `loadErrors`; `loadErrors` declarado y reiniciado en `loadRemote()` |
| `web/js/app.js` | `systemBanner()` en `renderShell()`; acción `run-diagnostic` conectada a `runFinalDiagnostic()`; `canManageCatalog()` aplicado a los botones de disciplina, grado y grupo (3 pantallas) |

## Configuración y documentación (2)

| Archivo | Cambio |
|---|---|
| `netlify.toml` | `[build.environment] NODE_VERSION = "22"` |
| `DEPLOYMENT_CHECKLIST.md` | Reescrito: orden 001→017, cuenta de dirección antes de 015, verificación y recuperación |

## Bump de build 12 → 13 (6)

`web/config.js` · `web/index.html` · `web/service-worker.js` ·
`android/app/build.gradle` · `scripts/test-governance-v160.mjs` ·
`scripts/test-production-v160.mjs` · `scripts/test-receipts-v160.mjs`

## Otros

- `package.json`: script `test:sql` y suite SQL añadida a `test`. El comando
  `build` que ejecuta Netlify **no se ha modificado**.
- `android/app/src/main/assets/www/**`: regenerado por `scripts/build.mjs`
  (copia verificada por SHA-256 de `web/`).

## Sin tocar

Ninguna otra migración, ninguna Edge Function, ninguna política RLS, ninguna
firma de RPC, `web/css/app.css`, `web/js/push.js`, `web/js/demo-data.js`,
`scripts/build.mjs` ni el resto de suites.
