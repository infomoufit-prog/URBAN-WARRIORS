# R64.2 deployment/readiness checklists

## Supabase
- [ ] Backup/snapshot target DB.
- [ ] Review both R64.2 migrations.
- [ ] Confirm prior R64 commercial migrations are present.
- [ ] Apply migrations in timestamp order.
- [ ] Verify Urban Warriors resolves to the expected ID/slug before accepting pilot assignment.
- [ ] Verify Urban Premium + no active permanent Commerce.
- [ ] Test RLS/authenticated Club management.
- [ ] Test plan request and admin approval in non-production first.

## Stripe
- [ ] Keep Standard connected accounts + direct charges.
- [ ] Verify application fee percentages by active plan.
- [ ] Verify Ticketing buyer fee separately.
- [ ] Verify refund/application-fee reversal behavior.
- [ ] Do not enable live recurring SaaS billing until its lifecycle is approved/tested.

## Netlify/PWA
- [ ] Run local build.
- [ ] Confirm web = dist.
- [ ] Smoke test onboarding, Plan y servicios, Showcase, Events.
- [ ] Verify PDF commercial asset.
- [ ] Deploy only after explicit authorization.

## Android
- [x] versionCode 20113 prepared.
- [x] embedded assets synced.
- [x] Firebase config present.
- [ ] create/provide local `android/keystore.properties`.
- [ ] assemble/sign release only after authorization.
- [ ] validate installed update path.
- [ ] Play upload only after authorization.

## Manual pilot QA
- [ ] Login as Urban Warriors.
- [ ] Confirm Premium in Plan y servicios.
- [ ] Club -> Showcase opens management directly.
- [ ] Create/edit Showcase product; verify 15-model limit.
- [ ] Confirm Commerce not permanently active.
- [ ] Club -> Events opens event workspace.
- [ ] Create draft and validate Premium publication quota.
- [ ] Test spectator/minor purchase restrictions.
- [ ] Test admin commercial requests queue.
