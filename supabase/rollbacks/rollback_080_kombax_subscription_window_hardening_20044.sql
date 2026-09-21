-- SAFETY BLOCKED: 080 corrects a temporal integrity failure found by transactional QA.
-- Do not roll back independently in production; restore the complete certified build if necessary.
select 'ROLLBACK_BLOCKED_080_BUILD_20044' as status;
