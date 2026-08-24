# KOMBAX RC13 build 20074 · Team Email Invitation Validation

## Scope
Restores the secure nominative team invitation flow: club Direction enters recipient email + role, KOMBAX creates a single-use `EQP-...` invitation bound to that email, and the recipient must authenticate/register with the same email before activation.

## Implemented
- `Equipo` → `Invitar al equipo por email` visible to Dirección.
- Required recipient email and required role; optional recipient name.
- Uses existing `app_kombax_invitacion_crear_v059` secure backend contract.
- Single-use code, email-bound, club-bound, role-bound, expiry 7 days.
- New protected Edge Function `invite-email`, JWT required, deployed ACTIVE v1.
- Email send has copy/share fallback if provider configuration or delivery fails.
- Recipient UI accepts `EQP-...` codes, validates code+email before authentication, and consumes `app_kombax_invitacion_aceptar_equipo_v059` after authentication/email confirmation.
- Generic numeric team code remains available as the alternative request/approval flow.

## Live backend verification
Synthetic invite created for `qa-team-20074@kombax.invalid` and role `monitor`:
- matching email validation: PASS (`valid=true`)
- different email validation: PASS (`valid=false`)
- synthetic row cleanup: PASS (`remaining=0`)
- unauthenticated `invite-email` invocation: PASS (HTTP 401)

No real invitation email was sent during QA.

## Regression
- `npm test`: PASS
- `node scripts/build.mjs`: PASS
- Build parity: 73 files, `web = dist = Android`
- Android preflight: 4/5; only local release keystore remains pending.

## Remaining E2E
Authorized real email delivery through Resend/Supabase must be validated later with a real test mailbox after hosted email configuration is confirmed.
