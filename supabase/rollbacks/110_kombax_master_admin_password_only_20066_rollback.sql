-- Rollback KOMBAX 20066 / 110: retirar acceso maestro password-only.
begin;
drop function if exists public.app_kombax_platform_admin_password_complete_v110(uuid);
notify pgrst,'reload schema';
commit;
