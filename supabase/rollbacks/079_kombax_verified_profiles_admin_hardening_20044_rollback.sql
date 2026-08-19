begin;
do $$ begin raise exception 'ROLLBACK_079_BLOCKED_VERIFIED_PROFILE_CONTINUITY'; end $$;
rollback;
