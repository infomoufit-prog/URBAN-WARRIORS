begin;
do $$ begin raise exception 'ROLLBACK_077_BLOCKED_VERIFIED_PROFILE_CONTINUITY'; end $$;
rollback;
