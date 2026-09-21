# KOMBAX 20.108 R58 — Identity, Memberships, Spectator & Media

Base: KOMBAX 20.107 R57.

## Implemented
- Administrative student records can exist without a KOMBAX/Auth account.
- Personal student invitation activates the existing record instead of creating a duplicate.
- One global KOMBAX account can activate independent memberships in different clubs.
- Duplicate account-to-student linkage inside the same club is blocked.
- Club membership access status is separate from the administrative member status.
- Club withdrawal/suspension revokes only that club membership; the global account remains.
- A global account without active memberships/authorized profiles operates as Spectator.
- Spectator does not receive Social or Showcase publishing permissions and does not get Mi Club/Mis clubes from registration alone.
- Spectator can contact a club as a prospective student through a dedicated inquiry channel.
- Spectator can request information about Showcase products through product-scoped conversations, without opening Social chat/Mi Red permissions.
- New verified profile type: Media / Creador, separate from Promotora/Profesional, limited to Social + Showcase/public profile capabilities.
- Minor-safe activation keeps the child's administrative record separate and links the authorized tutor account.

## Database
Migration: `supabase/migrations/249_kombax_identity_memberships_media_r58.sql`.
This migration must be reviewed/applied in the target Supabase environment before authenticated end-to-end QA of the new flows.

## QA status in package
- Modified JS syntax: PASS.
- Focused R58 static/integration-contract QA: PASS.
- R57 regression test reaches its historical "Showcase unchanged" assertion and fails there by design because R58 intentionally changes Showcase.
- Web/dist/Android asset parity is rebuilt by `node scripts/build.mjs`.

## Required manual/Work QA
Test two clubs with the same person, independent activation/deactivation, imported Excel members, repeated imports, verified-email activation, tutor/minor flows, Spectator restrictions, club inquiries, Showcase inquiries, Media verification/publishing, and Supabase RLS isolation.
