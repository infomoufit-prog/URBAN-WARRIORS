# KOMBAX 20.101 R17 · Android Fighter Image Hardening

## Cause confirmed
- Supabase RPC returns fighter URLs correctly.
- The installed APK was not rebuilt from R16; therefore backend-only validation was insufficient.
- R17 makes the Urban Warriors demo independent from remote fighter image delivery on native/local runtimes.

## Scope
- Deterministic local image mapping for all 12 Urban Warriors demo fighters.
- Apply broken-image fallback to Fight Cards, participant cards, Main Event and teaser images.
- Preserve remote URLs for real events and PWA production.
- Verify mapped assets are physically present in both web and Android packaged assets.

## Closure criterion
A build is not considered repaired unless the dedicated R17 test confirms the renderer references packaged Android assets and the full regression build passes.
