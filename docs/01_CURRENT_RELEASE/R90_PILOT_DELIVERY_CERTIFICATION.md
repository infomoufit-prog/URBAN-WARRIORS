# KOMBAX R90 build 20143 · Pilot Delivery Certification

This package is the cumulative continuation of the certified R89 build 20142 base.

## Certified changes
- Premium post-login Home built from official KOMBAX brand assets.
- Persistent **Recursos KOMBAX** access to Guides and Consulting in the private sidebar.
- Additional Guides/Consulting access in Mi Club hub.
- Premium hero surfaces for Guides and Consulting.
- Explicit PDF Open and Download actions.
- Android native bundled-PDF open/save bridge using a private FileProvider cache.
- 8-language i18n coverage for all new R90 UI.

## Integrity / QA
- `npm test`: PASS.
- `npm run release:build`: PASS.
- Dedicated R90 gate: 35/35 PASS.
- 556-file parity: `web = dist = android/app/src/main/assets/www`.
- 53 guide catalogue entries validated; 56 physical guide PDFs packaged in each runtime surface.
- Secret/signing scan: PASS, no local signing material included.
- Android preflight: 4/5, with local signing as the only intentionally pending item.
- Gradle wrapper cannot download Gradle 8.11.1 in the certification environment because `services.gradle.org` is not resolvable; compilation is therefore performed on the owner's Android Studio machine.

## Supabase
R90 is a UI/Android delivery and requires no new database migration. The cumulative R83→R89 migrations remain packaged and live. Health is ACTIVE on build 20143 (Edge Function v37).

## Continuity
R90 build 20143 becomes the only valid cumulative base for subsequent KOMBAX changes.
