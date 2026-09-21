-- SMOKE transaccional 083 · no persiste datos.
begin;
do $$
declare v_author uuid;v_post uuid;v_audience text;
begin
  select id into v_author from public.kombax_social_perfiles order by creado_en limit 1;
  if v_author is null then raise exception 'TEST_083_REQUIRES_SOCIAL_PROFILE'; end if;
  insert into public.kombax_social_publicaciones(autor_perfil_id,tipo,texto,estado)
  values(v_author,'actualizacion','SMOKE 083 PUBLIC DEFAULT','activa') returning id,audiencia into v_post,v_audience;
  if v_audience <> 'publica' then raise exception 'TEST_083_PUBLIC_DEFAULT_FAILED'; end if;
  begin
    update public.kombax_social_publicaciones set audiencia='club',audiencia_club_id=null where id=v_post;
    raise exception 'TEST_083_TARGET_CONSTRAINT_MISSING';
  exception when check_violation then null;
  end;
end $$;
rollback;
