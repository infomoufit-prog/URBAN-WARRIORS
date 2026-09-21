# KOMBAX i18n · Arquitectura B01

## Stack real detectado

KOMBAX R73 usa frontend **ES Modules JavaScript** servido desde `web/`, replicado de forma determinista a `dist/` y `android/app/src/main/assets/www/`. No usa React. Backend: Supabase REST/RPC/Edge Functions, PWA y wrapper Android.

## Decisión

Se implementó una capa nativa y pequeña bajo `web/js/i18n/`, evitando introducir una dependencia o una segunda arquitectura paralela.

### Núcleo

- `locale-metadata.js`: supported/enabled, metadata, normalización regional (`es-ES→es`, `en_US→en`, `tl-PH→fil`).
- `locale-storage.js`: prioridad cuenta → local → navegador/sistema → maestro.
- `resources.js`: registro único de recursos.
- `index.js`: `t()`, interpolación, fallback, estado global de locale, eventos de cambio y wrappers de formato.
- `formatters.js`: número, moneda, fecha, fecha/hora, porcentaje y plural rules basados en `Intl`.
- `ui.js`: selector reutilizable y binding.
- `locales/es/*`: 22 namespaces semánticos; no existe un archivo monolítico de traducciones.
- `locales/{en,fr,pt,it,de,th,fil}/index.js`: locales instalados pero no activados hasta sus fases.

## Persistencia de cuenta

La migración `20260914230000_kombax_i18n_locale_preference_b01.sql` añade `perfiles.preferred_locale` y dos RPC autenticadas. Es aditiva, no duplica tablas y no se despliega automáticamente. Si la migración todavía no está aplicada, KOMBAX conserva la preferencia local sin bloquear la UI.

## Fallback

`selected locale → en → es`. En B01 solo `es` está enabled. Los demás están supported pero ocultos/deshabilitados para uso público hasta superar su gate.

## Límites protegidos

- USER_CONTENT permanece original.
- ASSET_TEXT no se somete a OCR ni recreación.
- Rutas canónicas permanecen iguales.
- QR/ticket IDs y tokens no dependen del locale.
- Stripe y lógica comercial no se modifican en B01.

## Block 2 additions — F06–F10

- All 8 locales now carry the same **22 namespace files + index** structure.
- `es` remains the master locale; `en` is the first translated locale publicly enabled after QA.
- FR/PT/IT/DE/TH/FIL are installed and structurally complete but remain disabled until later integration/visual gates.
- Regional formatting uses `localeTag(getLocale())`; explicit `es-ES` is permitted only in the canonical locale-to-BCP47 map.
- Number/currency/date/date-time/percent/plural rules are centralized in `web/js/i18n/formatters.js` and exposed by `web/js/i18n/index.js`.
- Currency, country, timezone, jurisdiction and language are independent inputs. A locale change never changes a QR token, ticket ID, Stripe object, route or stored business identity.
- Thai uses locale-scoped CSS so Unicode shaping/wrapping is not solved by globally shrinking typography.


## Block 3 additions — F11–F15

- Product namespaces expanded from 229 to **475 master keys** while preserving the same semantic namespace architecture across 8 locales.
- `user_locale` now crosses the frontend/backend boundary for Assist/Migrations and selected system channels. One Luna/router architecture remains; no per-language agent copies were introduced.
- Email, push/notification and generated-finance-document system presentation can select locale independently from business data.
- Currency remains an explicit business input (EUR in existing flows), not derived from locale.
- Legal metadata is explicitly modeled as `locale`, `jurisdiction`, `legal_version`; translation never implies legal adaptation.
- QR/ticket identity is unchanged by locale.
- Generated Thai finance PDFs use explicit English fallback under the current standard-font constraint rather than emitting broken glyphs.

## B04 · Rollout seguro

`web/js/i18n/rollout.js` mantiene metadatos de gate separados de `SUPPORTED_LOCALES` / `ENABLED_LOCALES`. Esto permite instalar traducciones sin publicarlas. Un locale adicional sólo debe pasar a enabled tras QA visual y funcional autenticado, sin modificar rutas, IDs, moneda o jurisdicción.

## Post-freeze extraction remediation (RB01)

Catalog completeness and source extraction completeness are now separate metrics. ES/EN are strict active catalogs. Supported-but-disabled locales may fall back EN→ES for newly extracted keys until their own translation/QA block is completed. `scripts/i18n-hardcode-audit.mjs` is the source-debt detector and must not be replaced by catalog percentages. User-authored content remains original; `web/js/i18n/user-content-translation.js` only defines a future derived-translation request contract and performs no translation or mutation.
