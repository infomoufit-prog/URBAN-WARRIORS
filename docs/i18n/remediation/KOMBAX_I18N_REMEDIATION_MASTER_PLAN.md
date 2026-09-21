# KOMBAX i18n · Remediación post-freeze

## Objetivo

Cerrar la diferencia detectada entre **cobertura del catálogo** y **cobertura real de toda la aplicación**. El criterio de producto es:

- todo texto generado por KOMBAX debe poder localizarse;
- anuncios, landings, onboarding, UI, admin, estados, errores, ayudas, emails, push, PWA, documentos y copy comercial son `KOMBAX_GENERATED_CONTENT` y deben usar i18n;
- contenido creado por usuarios conserva siempre el original;
- una futura función «Ver traducción» puede generar una traducción derivada sin sustituir ni mutar el original;
- nombres propios, IDs, rutas, tokens QR, identificadores Stripe y otros valores técnicos no se traducen.

## Modelo de ejecución

La remediación se divide en 10 fases, dos bloques de cinco. Cada bloque termina obligatoriamente en un ZIP completo acumulativo y verificado.

### RB01 · R01-R05

1. **R01 — Auditoría exhaustiva y gate de hardcodes.** Crear un escáner reproducible que distinga candidatos UI, límites de contenido usuario y valores técnicos. Corregir el validador para diferenciar idiomas activos y soportados/ocultos.
2. **R02 — Landing, marketing, gateway y autenticación de entrada.** Migrar el public overview, copy comercial, presentación de identidades, acceso inicial, directorio de club y autenticación global.
3. **R03 — Componentes comunes y superficies compartidas.** Migrar copy reutilizable, accesibilidad, media, estados y helpers de interfaz.
4. **R04 — Perfiles y Finanzas prioritarias.** Migrar Sports Profile, Public Profile prioritario y shell/recibos/wallet/Stripe de Finanzas. Inventariar deuda profunda residual.
5. **R05 — Social prioritario + regresión + handoff.** Migrar Social Network y capas prioritarias de Social, mantener user content original, añadir contrato futuro de traducción derivada y cerrar QA.

### RB02 · R06-R10

6. **R06 — Showcase / Commerce completo + residuos de perfiles/finanzas/admin.**
7. **R07 — Events / Ticketing completo.**
8. **R08 — Social profundo + anuncios/promociones + resto de UI privada.**
9. **R09 — Páginas públicas, legal, Auth emails, push, backend copy, PDFs/documentos y PWA.**
10. **R10 — Sweep global, QA ES/EN y gate de lanzamiento.** El objetivo es que con locale EN no quede copy KOMBAX visible en español; los únicos originales no localizados serán user content/nombres propios/valores técnicos explícitamente clasificados.

## Estado tras RB01

RB01 amplía y corrige la cobertura, pero **no declara todavía la aplicación completa en inglés**. La deuda residual se conserva como evidencia machine-readable en `KOMBAX_I18N_HARDCODE_AUDIT.json` y se cierra en RB02.
