# R64.2 rollback / recovery runbook

R64.2 uses additive/compensating migrations and intentionally avoids destructive schema rewrites. Prefer a forward compensating migration over dropping production objects.

## Before applying R64.2 migrations
- take a database backup/snapshot;
- export current definitions of every function replaced by the two R64.2 migrations;
- record current Urban Warriors subscription/terms/entitlements;
- verify migration order.

## If rollback is required after DB application
1. Stop new commercial approvals temporarily.
2. Restore the pre-R64.2 definitions of the replaced functions from the target-environment backup / R64.1 schema snapshot.
3. Disable, rather than hard-delete, R64.2-only commercial requests/entitlements created after cutover where possible.
4. For Urban Warriors, revert only the pilot subscription row whose provider/reference are `kombax_pilot_r642` / `urban-warriors-premium`; do not touch unrelated subscriptions.
5. Revalidate Showcase/Events permissions and RLS.
6. Restore R64.1 web/dist/Android artifacts from the supplied baseline ZIP.
7. Run R64.1 regression suites before reopening.

No automatic destructive rollback SQL is included because it could overwrite legitimate production activity created after migration. Recovery must be compensating and based on the target environment's pre-migration snapshot.
