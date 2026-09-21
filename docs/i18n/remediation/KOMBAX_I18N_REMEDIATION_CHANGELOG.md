# KOMBAX i18n · Remediation changelog

## RB01 · R01-R05 · 2026-09-15

### R01 — Auditoría y gates
- Añadido `scripts/i18n-hardcode-audit.mjs`.
- Añadidos scripts `i18n:hardcode-audit` y `i18n:hardcode-gate`.
- El gate distingue `SYSTEM_UI_CANDIDATE`, `TECHNICAL_OR_DIAGNOSTIC` y `USER_CONTENT_BOUNDARY`.
- El validador i18n pasa a ser estricto para ES/EN y fallback-aware para locales soportados pero desactivados.
- Corregido el flattening de arrays de traducción para que listas localizadas formen claves reales `.0`, `.1`, etc.
- Tests históricos B02/B03/B04 adaptados para permitir crecimiento acumulativo del catálogo sin perder claves previas.

### R02 — Landing / marketing / gateway
- Nuevo namespace `marketing` para los 8 locales.
- ES y EN contienen copy real de la landing, perfiles, acciones, gateway, directorio y autenticación.
- FR/PT/IT/DE/TH/FIL mantienen fallback seguro mientras siguen desactivados.
- `public-product-overview.js` migrado a claves semánticas.
- `gateway.js` migra presentación de identidades, home, directorio de clubs y autenticación global a i18n.

### R03 — Common UI
- Ampliadas claves `common` de accesibilidad, media, estados y personas.
- `ui/components.js` migra copy compartido prioritario.

### R04 — Perfiles / Finanzas
- Ampliado `profile` ES/EN.
- `sports-profile.js` migra su presentación/formularios prioritarios a claves.
- `public-profile.js` migra álbum, posts, resultados, Showcase, facts deportivos y Discovery prioritarios sin traducir `p.texto`, bios, nombres ni descripciones creadas por usuarios.
- Ampliado `finance` ES/EN para Stripe, recibos, wallet, labels y acciones.
- `finance.js` migra estados y copy prioritario de recibos/wallet/Stripe.

### R05 — Social / policy
- `social-network.js` migra labels, solicitudes y estados prioritarios.
- `kombax-social.js` migra taxonomía y capas prioritarias manteniendo posts/comentarios originales.
- Añadido `user-content-translation.js` como contrato seguro para una futura función «Ver traducción» derivada; no ejecuta traducciones ni altera el original.
- Añadido `test-kombax-i18n-remediation-rb01.mjs`.


## RB02 · R06-R10 · 2026-09-15

### R06 — Showcase / Commerce + deep runtime extraction
- Extended audited localization across Showcase/Commerce and remaining product UI.
- Added legacy runtime compatibility localization that is allowlisted to KOMBAX-owned copy and excludes user-authored product content.

### R07 — Events / Ticketing + Social/Admin deep extraction
- Extended exact/contextual EN coverage through Events/Ticketing, Social deep surfaces, Platform Admin, clubs/federations/profiles and operational modules.
- QR/ticket identifiers, routes and technical IDs remain invariant.

### R08 — Global runtime copy gate
- Added global `--all --strict` runtime copy audit across `web/js`.
- Added 2,180 exact reviewed historical EN phrases and quality gate with placeholder/residue checks.
- Final runtime audit: 4,715/4,715 KOMBAX copy pieces covered; 0 unresolved; 366 technical/user fixtures classified and skipped.

### R09 — Public surfaces / PWA / Auth / system channels
- Privacy, Terms, Child Safety and Delete Account now localize ES/EN on canonical routes.
- Added locale-aware PWA manifest selection.
- Added six bilingual Supabase Auth templates driven by `preferred_locale`.
- Propagated locale through Stripe Checkout/refunds, push/session system copy, invitation email, finance reports and Assist/Migrations.
- Replaced transport/backend user-facing Spanish errors with stable neutral codes where appropriate; client errors localize before render.

### R10 — English implementation freeze gate
- Added public-surface and system-channel auditors and integrated them into cumulative `npm test`.
- English exact-copy gate: 2,180/2,180; 0 placeholder drift; 0 strong Spanish residue.
- Public surfaces: 92/92 localized; 0 unresolved.
- System channels: 8/8 PASS.
- `npm test` PASS; build 417 files PASS; Legal Gate PASS; Android preflight 4/5 only because local signing config is intentionally external.
- English software-copy implementation is complete under automated gates. Authenticated/manual visual/E2E QA remains a release gate.
