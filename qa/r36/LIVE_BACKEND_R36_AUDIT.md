# KOMBAX 20.101 R36 — Live backend audit

Project: poggsobhtutbuagjiydc

Verified after R36 migrations:
- 7 R36 tables have RLS enabled.
- Private R36 RPCs: anon EXECUTE=false; authenticated EXECUTE=true; SECURITY DEFINER; search_path="".
- Public projection RPC is intentionally callable by anon/authenticated and returns only the authorized projection for a connected event.
- Fighter Discovery/Invitation RPCs do not reference kombax_weight_measurements_v216 or kombax_competition_preparations_v216.
- Current R36 row counts at verification: connections=0, fighter-discovery profiles=0, invitations=0.
- No private weight history is used by Fighter Discovery.

Migrations applied live:
- kombax_event_connections_publication_r36
- kombax_fighter_discovery_invitations_r36
- kombax_r36_privacy_audit_hardening
