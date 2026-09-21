# KOMBAX RC13 build 20075 · Student/Family Email Invitation Validation

## Scope
Extends the secure nominative invitation architecture from team members to students/families while preserving the existing reusable club access code.

## Architecture verified
KOMBAX already contained backend support in migration 059 for two nominative invitation types:
- `equipo` → `EQP-XXXXXXXXXX`
- `alumno` → `ALU-XXXXXXXXXX`

The student path was not reachable end-to-end from the current UI and the Edge Function was restricted to team invitations.

## Implemented in 20075
- `Alumnos` → `Invitar alumno por email`.
- Required recipient email; optional recipient name.
- Intended recipient can be:
  - student aged 16+ registering their own account;
  - parent/mother/guardian creating the family/minor flow.
- Personal `ALU-...` code:
  - bound to club;
  - bound to exact email;
  - single use;
  - 7-day expiry.
- Recipient link uses `access_type=alumnos` and `access_code=ALU-...`.
- Before creating an Auth account, KOMBAX validates code + exact recipient email.
- Existing reusable numeric `Código alumnos/familias` remains available as a separate general onboarding flow.
- `invite-email` Edge Function v2 now supports both `equipo` and `alumno` and remains JWT-protected.

## Architecture defect found and repaired
The legacy table constraint from migration 007 only allowed staff roles in `invitaciones_club.rol` even though migration 059 later introduced `tipo_invitacion='alumno'` and attempted to store `rol='alumno'`.

Live creation initially failed with constraint `invitaciones_club_rol_check`.

Migration 130 fixes this by:
- allowing `alumno` in the invitation role constraint;
- replacing the old pending unique index `(club_id, email)` with `(club_id, email, tipo_invitacion)`, allowing a person to hold separate pending student and team invitations without duplicate invitations of the same type.

Migration applied live: `kombax_student_email_invitation_constraint_20075`.

## Live verification
Synthetic `ALU-...` invitation:
- creation: PASS
- correct email: `valid=true`
- different email: `valid=false`
- team invitation for same email can coexist: PASS
- all synthetic rows removed: PASS (`remaining=0`)

Edge Functions:
- `invite-email` v2 ACTIVE, `verify_jwt=true`
- unauthenticated invocation: PASS / HTTP 401
- `health` v3 ACTIVE
- live health: HTTP 200, `build=20075`, `db=ok`

No real invitation email was sent during QA.

## Regression / build
- Full `npm test`: PASS
- `node scripts/build.mjs`: PASS
- runtime parity: 73 files, `web = dist = Android`
- old `urban01.netlify.app` runtime references: 0
- high-risk secret scan: PASS
- Android preflight: 4/5; only local release signing remains pending.

## Remaining E2E
Send one real team invitation and one real student/family invitation to controlled mailboxes, then verify:
1. delivery;
2. branded sender/template;
3. link opens KOMBAX;
4. exact-email binding;
5. account confirmation when needed;
6. final role/student-family onboarding.
