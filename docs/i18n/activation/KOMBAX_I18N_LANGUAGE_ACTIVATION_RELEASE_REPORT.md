# KOMBAX · All-8 Language Activation Release Report

**Estado:** implementación completada bajo gates automáticos.

**Base:** KOMBAX 20124 R73 I18N REMEDIATION B02 R06-10

**Salida:** KOMBAX 20124 R73 I18N ALL8 ACTIVATED FINAL

## Resultado

Los ocho idiomas (`es`, `en`, `fr`, `pt`, `it`, `de`, `th`, `fil`) están soportados y habilitados. Cada locale dispone de las 1.077 claves maestras de forma directa y estricta. FR/PT/IT/DE/TH/FIL disponen además de 2.580 equivalencias directas de copy legacy, evitando una interfaz mezclada con inglés. Las páginas legales públicas, Auth y PWA también se han extendido a los ocho idiomas.

El contenido creado por usuarios permanece en su idioma original. Rutas, QR/ticket IDs, Stripe IDs, moneda y jurisdicción no se derivan del idioma.

## Gates

- All-8 activation gate: PASS
- npm test: PASS
- build: PASS (449 files; web = dist = Android)
- Legal Gate: PASS
- Android preflight: PARTIAL 4/5 únicamente por signing local externo

## No desplegado

No se ha realizado despliegue automático a Supabase, Netlify, GitHub o Google Play. Las migraciones preparadas permanecen versionadas en el ZIP.

## Release validation pendiente

QA manual autenticado en los ocho idiomas y validación de servicios externos autorizados.
