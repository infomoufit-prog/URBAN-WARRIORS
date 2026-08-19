begin;
do $$ begin raise exception 'ROLLBACK_072_BLOCKED_VERIFIED_PROFILE_CONTINUITY'; end $$;
rollback;
