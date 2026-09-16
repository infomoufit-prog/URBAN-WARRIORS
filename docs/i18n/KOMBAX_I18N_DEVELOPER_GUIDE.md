# KOMBAX i18n · Developer guide

## Add a new string
1. Choose the existing semantic namespace.
2. Add a stable English-style key to `web/js/i18n/locales/es/<namespace>.js`.
3. Add the same key to EN/FR/PT/IT/DE/TH/FIL, preserving any `{{placeholders}}` exactly.
4. Replace the UI literal with `t('namespace.semantic.key')`.
5. Run `npm run i18n:validate` and `npm test`.

Never use positional keys such as `text1`, `button2` or Spanish key names.

## Add a namespace
Create the same namespace file under every locale, then import/export it from each locale `index.js`. Run the validator; missing namespace/key symmetry fails the gate.

## Add a language
1. Add locale metadata and a BCP-47 mapping in the central formatter.
2. Create the locale directory with all namespaces.
3. Translate the master catalog; do not auto-translate user content or assets.
4. Validate placeholders, Unicode, formatting and typography.
5. Keep the locale **supported but disabled** until its activation gate passes.

## Validate a locale
Run:

```bash
npm run i18n:validate
npm run test:i18n:b02
npm test
npm run build
```

Then complete the appropriate product/visual/E2E gates. Catalog completeness alone is not sufficient for public activation.

## Activate a locale
Only add the locale to `ENABLED_LOCALES` after its required gate has passed. Activation must not change route, country, currency, timezone, jurisdiction, QR/token identity or Stripe identifiers.

## Formatting
Use the central i18n formatter exports instead of hardcoding `es-ES` or manual separators. Pass currency explicitly where money is formatted.
