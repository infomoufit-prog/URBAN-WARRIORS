-- 105 rollback · does not restore frontend behavior.
drop function if exists public.app_kombax_header_summary_v105(uuid);
drop index if exists public.idx_notificaciones_club_active_feed_v105;
