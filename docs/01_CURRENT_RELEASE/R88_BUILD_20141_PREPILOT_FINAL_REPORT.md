# KOMBAX R88 · build 20141 · Pre-pilot final cumulative report

## Base and scope

- Input base: KOMBAX R81 build 20134, then cumulative R82 Phase 2 package.
- Final runtime identity: `2.0.0-rc.13-r88-prepilot`, build `20141`.
- This package is cumulative. It preserves Social, Mi Club/private workspaces, Showcase, Events, Payments/Finance, Guides assets, PWA, Android and iOS source.
- No real card charge, SEPA debit, refund, mandate or money movement was executed during QA.

## Block 1 · Commerce / Finance

- Showcase Display remains catalog/contact mode when Commerce is not active.
- Showcase Commerce exposes Buy now, Add to cart, quantity and product variants where present.
- Cart is persistent and seller-isolated. A checkout never mixes different Connected Accounts.
- Multi-line Showcase checkout is prepared server-side by `app_stripe_checkout_prepare_cart_internal_r83`.
- Stripe account identity is derived server-side; arbitrary Connected Account ids from the client are not trusted.
- Checkout uses idempotency keys and signed webhook reconciliation.
- R87 reconciles the active webhook chain for multi-line cart stock and preserves the authoritative payment transition.
- Finance R84 is a transversal, identity-scoped read model over existing Club, Showcase, Events, Stripe and Terminal sources; it does not create a parallel accounting ledger.
- Methods modelled: online card, SEPA where supported, Tap to Pay Android, Tap to Pay iPhone source readiness and QR/web Checkout fallback.

## Block 2 · Home / identity / discovery

- New post-login Home order is fixed to: Social → Showcase → Events → Mi espacio.
- Mi espacio resolves the active identity context instead of mixing organization data.
- Existing Fighter Discovery and Events invitation engines were reused rather than duplicated.
- Fighter listing adds transparent sorting by availability, name or territory. No hidden ranking score is calculated and current/private weight tracking remains outside discovery.

## Block 3 · Guides / Consulting

- Guides UI packages the approved 15 base subjects and the detailed territorial layer for 19 territories.
- Search supports text and territory filtering and links to the approved PDFs and detailed master dossier.
- No regulatory requirement was invented in this phase. Case-specific obligations remain explicitly marked for verification.
- Consulting workflow supports request, context, documents, status history, quote acceptance and follow-up.
- The approved preparatory catalog contains 9 services. Every service remains `pricing_mode=quote` with `price_minor=null`; no unapproved price was invented.
- Consulting payment activation remains disabled until explicit commercial approval.

## Block 4 · Finance Premium / Training private layer

- Finance context is presented as accordions: Summary, Payments, Receipts, History, Reports, Debt, Orders, Sales and Ticketing.
- Showcase and Events can open the same transversal finance context when the active subject is resolved.
- KOMBAX Training is a separate private layer from the existing club session/attendance module.
- Training schema supports access grants, programs, modules, resources, enrollments, evaluations, attempts and credentials.
- No courses, hours, equivalences, licenses, certificates, partner names or prices are seeded because the real agreement/content has not been supplied.
- Training stays disabled unless the identity has an approved `training_enabled` access grant.

## Internationalization

- Enabled locales: ES, EN, FR, PT, IT, DE, TH and FIL.
- Strict validation passes for all eight locales.
- New pre-pilot surfaces were reviewed for real localization; English placeholder sentences were removed from FR/PT/IT/DE/TH/FIL.
- User-created source content is not overwritten by translation.

## Android / PWA / iOS source

- Web, `dist`, and Android WebView assets are byte-identical: 548 files each.
- Android: application id `com.urbanwarriors.app`, versionCode `20141`, compile/target SDK 36, min SDK 26, AGP 8.10.1, Gradle wrapper 8.11.1, Stripe Terminal 5.8.1.
- The previous Terminal build bug remains fixed: debug state uses `ApplicationInfo.FLAG_DEBUGGABLE`; no generated Stripe `BuildConfig.DEBUG` dependency is reintroduced.
- Release signing is deliberately external. No JKS, keystore, signing passwords or `android/keystore.properties` are included.
- iOS source is versioned to build 20141 but production signing/entitlements still require macOS/Xcode/Apple Developer setup.

## QA result

- `npm run release:build`: PASS.
- Full cumulative regression: PASS.
- R88 pre-pilot gate: 44/44 PASS.
- i18n strict: 8/8, 0 warnings.
- `web = dist = Android`: PASS, 548/548/548.
- Android Play static readiness: PASS.
- Android R52.1 build gate: PASS 13/13.
- Android release preflight: code/assets/Firebase/versioning PASS; local signing intentionally pending.
- Android debug Gradle invocation could not download Gradle 8.11.1 in this execution environment because outbound network access to `services.gradle.org` is blocked. Static Gradle/Play gates pass and the wrapper is packaged.
- Secret scan: no real signing files, private keys, Stripe secret keys or Supabase service-role credentials found. Archived/example placeholders are retained as documentation only.

This ZIP is the cumulative source package for repository replacement and pre-pilot deployment. Runtime deployment still requires the normal repository/Netlify process and local Android signing for APK/AAB.

## Optimización documental runtime

- Los PDF maestros aprobados de KOMBAX Guías se conservan intactos en `artifacts/guides`.
- Las copias runtime de Guías en `web`, `dist` y Android se optimizaron únicamente para tamaño de distribución, preservando número de páginas y contenido visual.
- Validación batch: 56/56 PDF runtime con conteo de páginas coincidente respecto al original.
- Tras la optimización se volvió a ejecutar el release build y se confirmó la paridad `web = dist = Android`.

