begin;
do $$ begin raise exception 'ROLLBACK_074_BLOCKED_VERIFIED_PROFILE_CONTINUITY'; end $$;
rollback;
