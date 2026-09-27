-- R104: reconcile public images uploaded after the last official branding update.
-- Only first-party images for the same club are eligible; prior branding is retained.
begin;

do $$
declare
  v_club public.clubes;
  v_logo text;
  v_cover text;
begin
  for v_club in
    select c.* from public.clubes c
    join public.perfiles_club_publicos p on p.club_id = c.id
    where p.actualizado_en > coalesce(c.branding_actualizado_en, '-infinity'::timestamptz)
      and (
        (p.logo_url is distinct from c.logo_url and p.logo_url like '%/club-public-media/' || c.id::text || '/public-club-logo/%')
        or (p.portada_url is distinct from c.portada_url and p.portada_url like '%/club-public-media/' || c.id::text || '/public-club-cover/%')
      )
  loop
    perform pg_advisory_xact_lock(hashtextextended(v_club.id::text, 39));
    select * into v_club from public.clubes where id = v_club.id for update;
    select
      case when p.logo_url is distinct from v_club.logo_url
              and p.logo_url like '%/club-public-media/' || v_club.id::text || '/public-club-logo/%'
           then p.logo_url else v_club.logo_url end,
      case when p.portada_url is distinct from v_club.portada_url
              and p.portada_url like '%/club-public-media/' || v_club.id::text || '/public-club-cover/%'
           then p.portada_url else v_club.portada_url end
      into v_logo, v_cover
      from public.perfiles_club_publicos p where p.club_id = v_club.id;
    if v_logo is distinct from v_club.logo_url or v_cover is distinct from v_club.portada_url then
      insert into public.club_branding_history(club_id, version, snapshot, motivo)
      values(v_club.id, v_club.branding_version,
        jsonb_build_object('theme_id', v_club.theme_id, 'logo_url', v_club.logo_url, 'portada_url', v_club.portada_url),
        'antes de sincronizar logo público')
      on conflict(club_id, version) do nothing;
      update public.clubes
         set logo_url = v_logo, portada_url = v_cover,
             branding_version = branding_version + 1,
             branding_actualizado_en = now(), actualizado_en = now()
       where id = v_club.id;
    end if;
  end loop;
end $$;

commit;
