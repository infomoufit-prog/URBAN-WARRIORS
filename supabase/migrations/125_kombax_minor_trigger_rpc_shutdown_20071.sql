-- KOMBAX RC13 build 20071 · 125
-- Los trigger functions de consentimiento de menores son internas a PostgreSQL
-- y nunca deben exponerse como RPC a anon/authenticated.
begin;
revoke all on function public.kombax_minor_social_consent_guard_v121() from public,anon,authenticated;
revoke all on function public.kombax_minor_direct_social_consent_guard_v121() from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
