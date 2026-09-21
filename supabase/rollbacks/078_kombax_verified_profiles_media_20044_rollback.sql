begin;
do $$ begin raise exception 'ROLLBACK_078_BLOCKED_VERIFIED_PROFILE_CONTINUITY'; end $$;
rollback;
