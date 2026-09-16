# KOMBAX 20.113 R64.2 — Implementation report

## Urban Warriors Premium pilot
- Urban Warriors is prepared as an active `premium` Club through an additive SQL migration.
- Premium benefits: Showcase Display up to 15 active models and 2 public Events per calendar month.
- Permanent Showcase Commerce is explicitly not enabled for Urban Warriors.
- The pilot assignment is guarded by the known Urban ID/slug and uses an identifiable pilot subscription reference.

## Showcase navigation
- Club hub `Showcase` now opens the existing management view directly.
- Product creation remains the existing `+ Nueva ficha` flow; no second product-management engine was added.
- Premium management UI states the 15-model limit and clearly indicates Commerce is not active.
- Base Club does not receive permanent Showcase publishing merely because a historical Club Showcase space exists.

## Events navigation and publication
- Club hub exposes KOMBAX Events directly.
- Base Club and verified Professional `promotor_organizador` may prepare drafts where permitted by existing workspace rules.
- Publication remains separately gated: `Publicar != Destacar != Ticketing`.
- Premium receives 2 public Events/month; Enterprise remains unlimited according to the commercial catalog.
- Punctual publication requests are scoped to a concrete event instead of being requested globally from the pricing page.

## Club onboarding and plan selection
- The two existing entry routes remain intact.
- A prospective new Club can view Club/Premium/Enterprise before account/application submission.
- Plan and billing choice are persisted with the Club application.
- Verification evidence remains mandatory for a new Club.
- After Club verification/provisioning, an auditable commercial plan request is created. Verification does not fabricate payment or silently activate a paid plan.

## Commercial administration
- Platform administration receives one commercial requests surface for plan requests and punctual entitlement requests.
- Admin can approve/reject supported manual requests after commercial/payment validation.
- Manual approval records activation but explicitly does not pretend a SaaS Stripe Billing charge happened.
- Ticketing continues to use its dedicated service review/activation flow and is not duplicated.

## Customer-facing pricing
- Enterprise break-even calculations are removed from customer UI and the updated commercial PDF.
- Founder/standard/annual pricing remains driven by commercial configuration.
- The PDF is documentation; structured commercial configuration remains the source of truth.

## Compatibility
- Existing Professional specialties are reused.
- Existing Showcase/Event/Ticketing engines are reused.
- New SQL is additive/compensating and intended to be applied only after environment review.
