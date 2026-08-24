# KOMBAX 20077 — Backup export gateway

Purpose: create real off-site logical backups on the current Supabase Free project without exposing the database password or a service-role/secret API key to the operator workstation.

## Security model
- Edge Function: `backup-export-20077`.
- Function uses Supabase-managed `SUPABASE_DB_URL` and server-only secret/service key environment variables.
- Client access uses a high-entropy short-lived capability whose SHA-256 only is stored in `kombax_backup_export_tokens_v141`.
- `anon` and `authenticated` have no table privileges on the token registry.
- Each request consumes one permitted use; capability has an expiry and can be revoked immediately.
- Storage buckets are never made public for backup.
- Responses are `no-store` and do not expose backend credentials.

## Export scope
- `public`: all application table rows except the backup capability registry itself.
- `auth`: durable identity/account rows; volatile session, refresh-token, OTP/flow/challenge state is intentionally excluded so stale credentials are not restored.
- `storage`: bucket/object metadata except internal migration/multipart state.
- Storage object bytes: exported individually through the same gated function.
- Schema/RPC/RLS/trigger definitions: source-controlled Supabase migrations are the authoritative schema backup and must be included in the backup package.

This is a logical application backup, not a physical PostgreSQL cluster snapshot. A restore drill must be performed into an isolated Supabase project/branch before marking disaster recovery PASS.
