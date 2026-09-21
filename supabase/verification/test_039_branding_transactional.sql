-- Ejecutar tras 039 en un entorno de prueba. Todo se revierte.
begin;

do $$
declare v_uid uuid; v_club uuid; v_version integer; v_result jsonb; v_other uuid;
begin
  select m.perfil_id,m.club_id into v_uid,v_club
  from public.miembros_club m where m.activo and (m.rol='direccion' or coalesce(m.coordinacion,false))
  order by m.creado_en limit 1;
  if v_uid is null then raise exception 'TEST_FIXTURE_REQUIRED: falta Gestor o Coordinación activo'; end if;

  perform set_config('request.jwt.claim.sub',v_uid::text,true);
  select branding_version into v_version from public.clubes where id=v_club;
  v_result:=public.app_publicar_branding_v039(v_club,v_version,'combat-dark',null,null);
  if coalesce((v_result->>'ok')::boolean,false) is not true then raise exception 'PUBLICACION_NO_OK'; end if;
  if (v_result->>'branding_version')::integer<>v_version+1 then raise exception 'VERSION_NO_INCREMENTADA'; end if;

  begin
    perform public.app_publicar_branding_v039(v_club,v_version,'combat-dark',null,null);
    raise exception 'CONFLICTO_NO_DETECTADO';
  exception when others then
    if sqlerrm='CONFLICTO_NO_DETECTADO' then raise; end if;
  end;

  select c.id into v_other from public.clubes c
  where c.id<>v_club and not exists(select 1 from public.miembros_club m where m.club_id=c.id and m.perfil_id=v_uid and m.activo)
  limit 1;
  if v_other is not null then
    begin
      perform public.app_publicar_branding_v039(v_other,(select branding_version from public.clubes where id=v_other),'combat-dark',null,null);
      raise exception 'AISLAMIENTO_TENANT_FALLIDO';
    exception when others then
      if sqlerrm='AISLAMIENTO_TENANT_FALLIDO' then raise; end if;
    end;
  end if;
end $$;

rollback;
