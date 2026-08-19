begin;
do $$ begin raise exception 'ROLLBACK_073_BLOCKED_VERIFIED_PROFILE_CONTINUITY'; end $$;
rollback;
