# KOMBAX RC13 build 20075

## Student/family nominative email invitations
- Added `Invitar alumno por email` to the Alumnos area.
- Added repository helpers for student invitations and generic invitation sending.
- Added `ALU-...` recipient flow with pre-registration email validation.
- Extended `invite-email` to support both team and student/family invitations.
- Preserved reusable numeric student/family club codes as a distinct onboarding mechanism.

## Backend repair
- Added migration 130 to repair the legacy invitation role constraint so `rol='alumno'` is valid.
- Pending invitation uniqueness now includes `tipo_invitacion`, allowing separate team/student invitations for the same recipient.

## Live verification
- ALU invitation creation PASS.
- Matching email PASS; wrong email blocked.
- Team + student invitation coexistence PASS.
- Synthetic QA data cleaned.
- `invite-email` v2 JWT protected; unauthenticated request HTTP 401.
- health v3 reports build 20075 / DB OK.

## Certification
- Full regression PASS.
- 73-file web/dist/Android parity PASS.
- Android release preflight 4/5 (local signing pending).
