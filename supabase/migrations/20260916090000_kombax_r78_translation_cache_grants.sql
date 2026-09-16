-- KOMBAX R78 · fixed system-copy translation catalog support.
-- The universal translation table already exists; R78 requires service_role to
-- seed precomputed system copy while public clients remain read-only under RLS.
grant select, insert, update, delete on table public.kombax_content_translations_u01 to service_role;
revoke insert, update, delete on table public.kombax_content_translations_u01 from anon, authenticated;
-- Build-only helper must never survive as an application RPC.
drop function if exists public.kombax_r78_i18n_batch_helper_temp(text, int[]);
