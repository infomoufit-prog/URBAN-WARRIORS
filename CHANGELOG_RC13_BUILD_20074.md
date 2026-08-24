# KOMBAX RC13 build 20074

- Restored nominative team invitations by recipient email.
- Direction now enters email + role when inviting a team member.
- Invitations use single-use `EQP-...` codes bound to the exact email.
- Recipient flow validates invitation email before acceptance.
- Generic numeric team access code remains available for manual request flow.
- Added and deployed JWT-protected `invite-email` Edge Function.
- Full regression PASS; web/dist/Android parity preserved.
