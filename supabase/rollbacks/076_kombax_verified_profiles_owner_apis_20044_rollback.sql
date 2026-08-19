begin;
do $$ begin raise exception 'ROLLBACK_076_BLOCKED_VERIFIED_PROFILE_CONTINUITY'; end $$;
rollback;
