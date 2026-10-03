-- R118 discovery correction rollback.
-- Reapply migration 319 function definition if strict rollback is required.
-- This file intentionally does not drop R118 endpoints or data.
select true;
