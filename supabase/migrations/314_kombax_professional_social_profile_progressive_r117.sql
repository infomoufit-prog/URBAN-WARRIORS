-- KOMBAX R117 build 20174 · Professional Perfil Social can be created before
-- choosing a specialty. If supplied, the specialty is validated. Verification
-- continues to require the professional data needed for verified capabilities.

do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_perfil_mutate_v196' and p.prokind='f';
  if d is null then raise exception 'KOMBAX_PROFILE_MUTATE_V196_NOT_FOUND'; end if;

  d:=replace(
    d,
    'if v_type=''profesional'' then' || chr(10) ||
    '      v_primary:=lower(btrim(coalesce(v_payload->>''especialidad_principal'','''')));v_secondary:=coalesce(v_payload->''especialidades_secundarias'',''[]''::jsonb);' || chr(10) ||
    '      if not public.app_kombax_professional_specialties_valid_v196(v_primary,v_secondary) then raise exception ''KOMBAX_PROFESSIONAL_SPECIALTY_INVALID'';end if;' || chr(10) ||
    '    end if;',
    'if v_type=''profesional'' then' || chr(10) ||
    '      v_primary:=lower(btrim(coalesce(v_payload->>''especialidad_principal'','''')));v_secondary:=coalesce(v_payload->''especialidades_secundarias'',''[]''::jsonb);' || chr(10) ||
    '      if v_primary='''' then' || chr(10) ||
    '        v_secondary:=''[]''::jsonb;' || chr(10) ||
    '      elsif not public.app_kombax_professional_specialties_valid_v196(v_primary,v_secondary) then' || chr(10) ||
    '        raise exception ''KOMBAX_PROFESSIONAL_SPECIALTY_INVALID'';' || chr(10) ||
    '      end if;' || chr(10) ||
    '    end if;'
  );

  d:=replace(
    d,
    'if v_type=''profesional'' then' || chr(10) ||
    '      insert into public.kombax_profesional_perfiles_v196(perfil_directo_id,especialidad_principal) values(v_profile.id,v_primary)' || chr(10) ||
    '        on conflict(perfil_directo_id) do update set especialidad_principal=excluded.especialidad_principal,actualizada_en=now();' || chr(10) ||
    '      delete from public.kombax_profesional_especialidades_secundarias_v196 where perfil_directo_id=v_profile.id;' || chr(10) ||
    '      for v_item in select distinct value from jsonb_array_elements_text(v_secondary) loop' || chr(10) ||
    '        insert into public.kombax_profesional_especialidades_secundarias_v196(perfil_directo_id,especialidad_codigo) values(v_profile.id,v_item) on conflict do nothing;' || chr(10) ||
    '      end loop;' || chr(10) ||
    '    end if;',
    'if v_type=''profesional'' and v_primary<>'''' then' || chr(10) ||
    '      insert into public.kombax_profesional_perfiles_v196(perfil_directo_id,especialidad_principal) values(v_profile.id,v_primary)' || chr(10) ||
    '        on conflict(perfil_directo_id) do update set especialidad_principal=excluded.especialidad_principal,actualizada_en=now();' || chr(10) ||
    '      delete from public.kombax_profesional_especialidades_secundarias_v196 where perfil_directo_id=v_profile.id;' || chr(10) ||
    '      for v_item in select distinct value from jsonb_array_elements_text(v_secondary) loop' || chr(10) ||
    '        insert into public.kombax_profesional_especialidades_secundarias_v196(perfil_directo_id,especialidad_codigo) values(v_profile.id,v_item) on conflict do nothing;' || chr(10) ||
    '      end loop;' || chr(10) ||
    '    end if;'
  );

  execute d;
end $$;

notify pgrst,'reload schema';
