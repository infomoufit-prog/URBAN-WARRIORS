begin;
do $$ begin raise exception 'ROLLBACK_075_BLOCKED_VERIFIED_PROFILE_CONTINUITY'; end $$;
rollback;
