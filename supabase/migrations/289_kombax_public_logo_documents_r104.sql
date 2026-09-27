-- R104: document snapshots take the logo from the public club profile.
-- Existing issued receipts and reports remain immutable.
begin;

create or replace function public.app_receipt_public_logo_r104()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  select coalesce(nullif(p.logo_url, ''), nullif(c.logo_url, ''))
    into new.emisor_logo_url
    from public.clubes c
    left join public.perfiles_club_publicos p on p.club_id = c.id
   where c.id = new.club_id;
  return new;
end $$;
revoke all on function public.app_receipt_public_logo_r104() from public, anon, authenticated;
drop trigger if exists zz_receipt_public_logo_r104 on public.recibos_cuota;
create trigger zz_receipt_public_logo_r104 before insert on public.recibos_cuota
for each row execute function public.app_receipt_public_logo_r104();

create or replace function public.app_finance_report_public_logo_r104()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_logo text;
begin
  -- pdf-lib embeds PNG/JPEG. Keep the last compatible logo until the public
  -- profile owner uploads a new PNG/JPEG through the R104 logo editor.
  select coalesce(
    nullif(case when p.logo_url ~* '[.](png|jpe?g)([?].*)?$' then p.logo_url end, ''),
    nullif(case when c.logo_url ~* '[.](png|jpe?g)([?].*)?$' then c.logo_url end, ''),
    (select h.snapshot->>'logo_url' from public.club_branding_history h
      where h.club_id = c.id and h.snapshot->>'logo_url' ~* '[.](png|jpe?g)([?].*)?$'
      order by h.version desc limit 1)
  )
    into v_logo
    from public.clubes c
    left join public.perfiles_club_publicos p on p.club_id = c.id
   where c.id = new.club_id;
  new.snapshot := jsonb_set(new.snapshot, '{club,logo_url}', coalesce(to_jsonb(v_logo), 'null'::jsonb), true);
  return new;
end $$;
revoke all on function public.app_finance_report_public_logo_r104() from public, anon, authenticated;
drop trigger if exists zz_finance_report_public_logo_r104 on public.informes_financieros;
create trigger zz_finance_report_public_logo_r104 before insert on public.informes_financieros
for each row execute function public.app_finance_report_public_logo_r104();

commit;
