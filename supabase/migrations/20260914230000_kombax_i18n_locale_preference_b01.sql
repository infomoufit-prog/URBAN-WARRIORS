-- KOMBAX 20124 R73 · i18n Block 01 · locale preference
-- Additive, non-destructive. Language is independent from country/currency/timezone/jurisdiction.

alter table public.perfiles
  add column if not exists preferred_locale text;

-- Existing data is not rewritten. The new column starts NULL and is populated only by the authenticated user.

alter table public.perfiles
  drop constraint if exists perfiles_preferred_locale_i18n_b01_check;
alter table public.perfiles
  add constraint perfiles_preferred_locale_i18n_b01_check
  check (preferred_locale is null or preferred_locale in ('es','en','fr','pt','it','de','th','fil'));

create or replace function public.app_kombax_get_preferred_locale_i18n_b01()
returns jsonb
language sql
stable
security invoker
set search_path=public
as $$
  select jsonb_build_object(
    'preferred_locale', p.preferred_locale
  )
  from public.perfiles p
  where p.id = auth.uid();
$$;

create or replace function public.app_kombax_set_preferred_locale_i18n_b01(p_locale text)
returns jsonb
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_locale text := lower(trim(coalesce(p_locale,'')));
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_locale not in ('es','en','fr','pt','it','de','th','fil') then raise exception 'KOMBAX_LOCALE_UNSUPPORTED'; end if;
  update public.perfiles
  set preferred_locale=v_locale, actualizado_en=now()
  where id=auth.uid();
  if not found then raise exception 'KOMBAX_PROFILE_REQUIRED'; end if;
  return jsonb_build_object('ok',true,'preferred_locale',v_locale);
end;
$$;

revoke all on function public.app_kombax_get_preferred_locale_i18n_b01() from public,anon;
revoke all on function public.app_kombax_set_preferred_locale_i18n_b01(text) from public,anon;
grant execute on function public.app_kombax_get_preferred_locale_i18n_b01() to authenticated;
grant execute on function public.app_kombax_set_preferred_locale_i18n_b01(text) to authenticated;

notify pgrst, 'reload schema';
