# KOMBAX RC13 build 20.097 · Final Packaging Certification

- Candidate: Events Workspace Isolation + Local Signing Transfer.
- Base: 20.096 Events Premium Visual Identity.
- Supabase migrations 171 and 172: applied to production backend.
- Urban Warriors public-event entitlement: intentionally NOT activated until 20.097 frontend deploy.
- `npm test`: PASS.
- `npm run build`: PASS.
- web = dist = Android: 102 files.
- Legal release gate: PASS.
- Android preflight: 4/5; signing config must be restored locally using the included JKS.
- JKS is intentionally present; plaintext passwords are absent.
