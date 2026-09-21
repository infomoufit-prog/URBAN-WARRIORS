# Supabase integration audit · KOMBAX 20.095

20.095 does not introduce a schema migration. Its backend task is reconciliation against the 20.094 production baseline.

## Observed production state

- `health` Edge Function: v14 ACTIVE, reports build 20094.
- `event-media-url`: v1 ACTIVE, public endpoint by design, but it resolves media through a service-role-only RPC and signs only eligible public event media.
- Signed event media TTL: 900 seconds.
- `kombax-events-media` bucket: private.
- internal resolver privilege: anon=false; authenticated=false; service_role=true.

## 20.095 staging rule

The repository contains `supabase/functions/health/index.ts` prepared for build 20095, but it was **not deployed** during packaging. This avoids a version lie while Netlify still serves the previous production build.

After Netlify 20.095 is live and validated, deploy the 20095 `health` source and re-check GET/HEAD headers.

## Security conclusion

No public Storage bucket was opened, no service role key is stored in frontend code, no direct client access to the internal media asset resolver was enabled, and no new anonymous write path was introduced.
