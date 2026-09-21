# KOMBAX 20.101 R19 · URBAN WARRIORS SHOWCASE PRODUCTS

## Base
- KOMBAX 20.101 R18 Urban Warriors Realism.

## Mission
Create three complete demo Showcase listings owned by the existing Urban Warriors club Showcase space, using durable product imagery and the real Showcase data model.

## Scope
1. Helmet / headguard demo listing.
2. Integral training gloves demo listing.
3. Sports nutrition / whey demo listing.
4. Durable HTTPS imagery in `kombax-public-media` and packaged local demo assets for PWA/Android continuity.
5. Complete supported Showcase fields: category, name, summary, description, image, price, currency, CTA and publication state.
6. Preserve product-scoped Showcase messaging and existing multiclub permissions.

## Data model decision
KOMBAX remains non-transactional: these are reference prices and the primary action is `contact` / `Me interesa`. Purchasing/payment is completed directly with the club outside KOMBAX.

## Risks
- Broken external image URLs -> mitigate with Supabase public Storage + packaged local copies.
- Cross-club leakage -> seed targets only the existing Urban Warriors Showcase brand and is idempotent.
- Duplicate demo products -> fixed slugs + upsert logic.
- Unsafe direct table access for users -> no permission changes; existing RPC architecture remains authoritative.

## Backend
- Apply a data seed migration to the main Supabase project after product images are uploaded.
- No new tables, no relaxed RLS, no new anonymous mutation privileges.

## QA / Closure
- Exactly 3 R19 Urban Warriors demo listings published.
- 3 distinct HTTPS image URLs; each externally reachable as an image.
- Public Showcase RPC returns all three with Urban Warriors as seller.
- Categories: Protecciones / Equipamiento / Nutrición deportiva.
- Prices: 79.90 / 64.90 / 49.90 EUR.
- CTA: contact / `Me interesa`.
- Anonymous read works through public Showcase RPC; anonymous mutation remains closed.
- Local images exist in web, dist and Android assets after build.
- Full regression and deterministic `web = dist = Android` pass.
- Android preflight reported truthfully; Signed APK only claimed if actually generated.
