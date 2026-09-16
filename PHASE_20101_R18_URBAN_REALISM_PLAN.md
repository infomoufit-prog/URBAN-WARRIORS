# KOMBAX 20.101 R18 · Urban Warriors Realism Pass

## Base
R18 Demo Event Image Routing Hardening, reconstructed from the verified delivery ZIP.

## Goal
Make Urban Warriors look like a credible real event using the 10 newly generated fictional fighter portraits.

## Scope
- 10 visible fictional participants, all with unique portraits.
- 5 fights total: 4 Fight Card + 1 Main Event.
- Exactly 1 Main Event.
- Reuse the same 10 portraits in the official event album.
- Preserve the real Events domain, permissions, Event Creator and multiclub isolation.
- Keep local packaged copies for PWA/Android and durable backend copies for normal event reads.

## Data decisions
- Keep: Malik Benítez, Bruno Sato, Aina Torres, Hana Ribeiro, Daniel Ortiz, Marc Vidal, Laia Costa, Emma León, Leo Martín, Hugo Ríos.
- Remove from this demo: Nico Serra, Ian Cruz.
- Fight structure is adapted to the available portrait ages/presentation.

## Risks
- Storage/media registration must remain consistent with the private event-media model.
- Seed reruns must not restore 12 participants / 6 fights.
- No duplicated portrait URLs.

## QA closure
- participant_count = 10
- unique_photo_count = 10
- fight_count = 5
- main_event_count = 1
- album_photo_count = 10
- web = dist = Android
- full regression PASS
