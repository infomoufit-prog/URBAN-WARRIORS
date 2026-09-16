# Backend hotfix · Urban Warriors fighter images

## Problem
The Urban Warriors fictitious event had 12 visible participants and 6 fights, but only two participant rows contained an image URL. Those URLs pointed at `kombax.es` static assets, while ten participants had `foto_url_externa = null`. Android therefore could render Fight Cards but showed broken/missing fighter images.

## Production repair
Applied directly to Supabase project `poggsobhtutbuagjiydc`.

- Added durable WEBP objects to public bucket `club-public-media` under the Urban Warriors club namespace.
- Updated all 12 Urban Warriors participant rows to HTTPS Supabase Storage URLs.
- Hardened `app_kombax_demo_urban_warriors_jiujitsu_seed_v180()` by wrapping the original seed so every future idempotent install/update reapplies valid fighter image URLs after rebuilding participants/fights.
- Kept the original seed implementation private as `..._v180_core()`; only the authenticated wrapper is executable.
- Temporary upload Edge Functions were disabled after use.

## Verified against production
- participants: 12
- participants with HTTPS image: 12
- references to `kombax.es`: 0
- fights: 6
- seed rerun: PASS / idempotent
- public Storage adult image: HTTP 200 `image/webp`
- public Storage youth image: HTTP 200 `image/webp`

## Source continuity
The recovery WEBP files are stored under:
`supabase/seed-assets/urban-warriors-jiujitsu-fighter-repair/`

The production migration is mirrored as:
`supabase/migrations/183_kombax_events_urban_fighter_storage_repair_20101.sql`

No new APK is required for the production data repair; R16 already renders HTTPS participant photos.
