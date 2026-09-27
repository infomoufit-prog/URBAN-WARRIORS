# R89 QA Scorecard

- R89 dedicated gate: PASS 48/48
- Accumulated npm test: PASS
- Legal gate: PASS
- Release build: PASS
- web/dist/Android parity: PASS (556 files)
- i18n 8 locales: PASS
- Secret scan: PASS
- Supabase migration live: PASS
- Supabase new RPC anon access: DENIED as intended
- Health live: ACTIVE v36 / build 20142
- Android preflight: PASS except local signing material (expected external prerequisite)
- Gradle compile: ENVIRONMENT BLOCKED (`services.gradle.org` DNS/network unavailable)
- Real payments executed: NO
