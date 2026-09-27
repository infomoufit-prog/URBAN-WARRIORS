-- R104: keep the club's official and public images in step.
-- Historical receipt logo snapshots remain untouched.
begin;

create or replace function public.app_sync_club_public_images_r104()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.perfiles_club_publicos p
     set logo_url = case when new.logo_url is distinct from old.logo_url then new.logo_url else p.logo_url end,
         portada_url = case when new.portada_url is distinct from old.portada_url then new.portada_url else p.portada_url end,
         actualizado_en = now(),
         actualizado_por = coalesce(auth.uid(), p.actualizado_por)
   where p.club_id = new.id
     and ((new.logo_url is distinct from old.logo_url and p.logo_url is distinct from new.logo_url)
       or (new.portada_url is distinct from old.portada_url and p.portada_url is distinct from new.portada_url));
  return new;
end $$;
revoke all on function public.app_sync_club_public_images_r104() from public, anon, authenticated;
drop trigger if exists clubes_sync_public_images_r104 on public.clubes;
create trigger clubes_sync_public_images_r104
after update of logo_url, portada_url on public.clubes
for each row when (old.logo_url is distinct from new.logo_url or old.portada_url is distinct from new.portada_url)
execute function public.app_sync_club_public_images_r104();

-- Preserve the existing mutation gateway and its adult registration validation.
-- Lock order matches app_publicar_branding_v039: advisory lock, club, public profile.
create or replace function public.app_mutate_v160(p_operation text, p_payload jsonb, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_dob date;
  v_age integer;
  v_club_id uuid;
  v_club public.clubes;
  v_old_logo text;
  v_old_cover text;
  v_new_logo text;
  v_new_cover text;
  v_current_logo text;
  v_current_cover text;
  v_result jsonb;
begin
  if p_operation = 'cuenta.registrar' and lower(coalesce(v_payload->>'tipo_cuenta', '')) = 'adulto' then
    begin
      v_dob := nullif(v_payload->>'fecha_nacimiento_adulto', '')::date;
    exception when others then
      raise exception 'Fecha de nacimiento no válida';
    end;
    if v_dob is null then raise exception 'La fecha de nacimiento es obligatoria para inscribirte como alumno'; end if;
    if v_dob > current_date then raise exception 'La fecha de nacimiento no puede ser futura'; end if;
    v_age := extract(year from age(current_date, v_dob))::integer;
    if v_age < 16 then raise exception 'KOMBAX_MINOR_MUST_USE_TUTOR_FLOW'; end if;
  end if;

  if p_operation = 'club_publico.guardar' then
    begin
      v_club_id := nullif(v_payload->>'club_id', '')::uuid;
    exception when others then
      raise exception 'MUTATION_INVALID_CLUB_ID';
    end;
    if v_club_id is not null and public.app_puede_gestionar_perfil_club_v035(v_club_id) then
      perform pg_advisory_xact_lock(hashtextextended(v_club_id::text, 39));
      select * into v_club from public.clubes where id = v_club_id for update;
      select p.logo_url, p.portada_url into v_old_logo, v_old_cover
        from public.perfiles_club_publicos p where p.club_id = v_club_id;
    end if;
  end if;

  v_result := public.app_mutate_v160_pre_student_age_r59(p_operation, p_payload, p_request_id);

  if p_operation = 'club_publico.guardar' and v_club.id is not null then
    v_new_logo := nullif(v_result#>>'{data,logo_url}', '');
    v_new_cover := nullif(v_result#>>'{data,portada_url}', '');
    select p.logo_url, p.portada_url into v_current_logo, v_current_cover
      from public.perfiles_club_publicos p where p.club_id = v_club_id;
    if v_current_logo is not distinct from v_new_logo
       and v_current_cover is not distinct from v_new_cover
       and (v_new_logo is distinct from v_old_logo or v_new_cover is distinct from v_old_cover) then
      perform public.app_publicar_branding_v039(
        v_club_id, v_club.branding_version, v_club.theme_id,
        case when v_new_logo is distinct from v_old_logo then v_new_logo else v_club.logo_url end,
        case when v_new_cover is distinct from v_old_cover then v_new_cover else v_club.portada_url end
      );
    end if;
  end if;
  return v_result;
end $$;
revoke all on function public.app_mutate_v160(text, jsonb, uuid) from public, anon;
grant execute on function public.app_mutate_v160(text, jsonb, uuid) to authenticated;

notify pgrst, 'reload schema';
commit;
