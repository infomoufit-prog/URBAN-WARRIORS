-- KOMBAX RC13 build 20053 · 098 · Club verification workflow
-- Refuerza datos mínimos, mantiene CIF/forma jurídica opcionales y obliga a revisar acreditación privada.
begin;

create or replace function public.app_kombax_club_payload_validate_v098(
  p_nombre_publico text,
  p_datos_publicos jsonb,
  p_datos_verificacion jsonb
) returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_pub jsonb:=coalesce(p_datos_publicos,'{}'::jsonb);
  v_ver jsonb:=coalesce(p_datos_verificacion,'{}'::jsonb);
  v_need text[]:='{}'::text[];
begin
  if char_length(btrim(coalesce(p_nombre_publico,'')))<2 then v_need:=array_append(v_need,'nombre_club'); end if;
  if btrim(coalesce(v_pub->>'ubicacion',''))='' then v_need:=array_append(v_need,'ubicacion'); end if;
  if jsonb_typeof(coalesce(v_pub->'disciplinas','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(v_pub->'disciplinas','[]'::jsonb))<1 then v_need:=array_append(v_need,'disciplinas'); end if;
  if btrim(coalesce(v_ver->>'nombre_legal',''))='' then v_need:=array_append(v_need,'nombre_legal'); end if;
  if btrim(coalesce(v_ver->>'email_oficial',''))='' or position('@' in coalesce(v_ver->>'email_oficial',''))<2 then v_need:=array_append(v_need,'email_oficial'); end if;
  if char_length(regexp_replace(coalesce(v_ver->>'telefono',''),'[^0-9+]','','g'))<6 then v_need:=array_append(v_need,'telefono'); end if;
  if btrim(coalesce(v_ver->>'responsable',''))='' then v_need:=array_append(v_need,'responsable'); end if;
  if btrim(coalesce(v_ver->>'rol_responsable',''))='' then v_need:=array_append(v_need,'rol_responsable'); end if;
  if char_length(btrim(coalesce(v_ver->>'evidencia','')))<3 then v_need:=array_append(v_need,'evidencia'); end if;
  if cardinality(v_need)>0 then raise exception 'KOMBAX_CLUB_FIELDS_REQUIRED:%',array_to_string(v_need,','); end if;
  return jsonb_build_object('valid',true,'scope','club_verification_v098','required_fields',jsonb_build_array('nombre_club','ubicacion','disciplinas','nombre_legal','email_oficial','telefono','responsable','rol_responsable','evidencia'));
end;
$$;
revoke all on function public.app_kombax_club_payload_validate_v098(text,jsonb,jsonb) from public,anon,authenticated;

create or replace function public.app_kombax_application_validate_v072(p_solicitud_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare
  v_req public.kombax_solicitudes_alta; v_direct public.perfiles_kombax_directos;
  v_docs integer:=0; v_dob date; v_age integer; v_identity public.identidades_sociales; v_socio public.socios;
  v_pub jsonb; v_ver jsonb;
  v_need text[]:='{}'::text[];
begin
  select * into v_req from public.kombax_solicitudes_alta where id=p_solicitud_id;
  if v_req.id is null then raise exception 'KOMBAX_APPLICATION_NOT_FOUND'; end if;
  if v_req.tipo not in ('club','competidor','marca','federacion') then raise exception 'KOMBAX_APPLICATION_TYPE_NOT_OPEN'; end if;
  if not coalesce(v_req.declaracion_aceptada,false) then raise exception 'KOMBAX_DECLARATION_REQUIRED'; end if;
  select count(*) into v_docs from public.kombax_verificacion_documentos d where d.solicitud_id=v_req.id and d.estado='active';
  if v_docs<1 then raise exception 'KOMBAX_VERIFICATION_DOCUMENT_REQUIRED'; end if;
  v_pub:=coalesce(v_req.datos_publicos,'{}'::jsonb); v_ver:=coalesce(v_req.datos_verificacion,'{}'::jsonb);

  if v_req.tipo='competidor' then
    if v_req.perfil_directo_id is null then raise exception 'KOMBAX_DIRECT_PROFILE_REQUIRED'; end if;
    select * into v_direct from public.perfiles_kombax_directos where id=v_req.perfil_directo_id and tipo='competidor';
    if v_direct.id is null then raise exception 'KOMBAX_COMPETITOR_PROFILE_REQUIRED'; end if;
    if jsonb_typeof(coalesce(v_pub->'disciplinas','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(v_pub->'disciplinas','[]'::jsonb))<1 then v_need:=array_append(v_need,'disciplinas'); end if;
    if btrim(coalesce(v_ver->>'nombre_legal',''))='' then v_need:=array_append(v_need,'nombre_legal'); end if;
    if btrim(coalesce(v_ver->>'email',''))='' or position('@' in coalesce(v_ver->>'email',''))<2 then v_need:=array_append(v_need,'email'); end if;
    if btrim(coalesce(v_ver->>'evidencia',''))='' then v_need:=array_append(v_need,'evidencia'); end if;
    if v_direct.origen_identidad_social_id is not null then
      select * into v_identity from public.identidades_sociales where id=v_direct.origen_identidad_social_id and perfil_id=v_req.perfil_id and estado='activa';
      if v_identity.id is null then raise exception 'KOMBAX_COMPETITOR_MEMBER_IDENTITY_INVALID'; end if;
      select * into v_socio from public.socios where id=v_identity.socio_origen_id and club_id=v_identity.club_origen_id and estado='activo';
      if v_socio.id is null or v_socio.fecha_nacimiento is null then raise exception 'KOMBAX_COMPETITOR_AGE_MUST_BE_CLUB_VERIFIED'; end if;
      v_dob:=v_socio.fecha_nacimiento;
    else
      begin v_dob:=nullif(v_ver->>'fecha_nacimiento','')::date; exception when others then v_dob:=null; end;
      if v_dob is null then v_need:=array_append(v_need,'fecha_nacimiento'); end if;
    end if;
    if v_dob is not null then
      v_age:=extract(year from age(current_date,v_dob))::integer;
      if v_age<16 then raise exception 'KOMBAX_COMPETITOR_MIN_AGE_16'; end if;
    end if;

  elsif v_req.tipo='marca' then
    if v_req.perfil_directo_id is null then raise exception 'KOMBAX_DIRECT_PROFILE_REQUIRED'; end if;
    if btrim(coalesce(v_pub->>'categoria',''))='' then v_need:=array_append(v_need,'categoria'); end if;
    if btrim(coalesce(v_pub->>'web_publica','')) !~* '^https://[^[:space:]]+$' then v_need:=array_append(v_need,'web_publica_https'); end if;
    if btrim(coalesce(v_ver->>'razon_social',''))='' then v_need:=array_append(v_need,'razon_social'); end if;
    if btrim(coalesce(v_ver->>'email_corporativo',''))='' or position('@' in coalesce(v_ver->>'email_corporativo',''))<2 then v_need:=array_append(v_need,'email_corporativo'); end if;
    if btrim(coalesce(v_ver->>'responsable',''))='' then v_need:=array_append(v_need,'responsable'); end if;
    if btrim(coalesce(v_ver->>'rol_responsable',''))='' then v_need:=array_append(v_need,'rol_responsable'); end if;
    if btrim(coalesce(v_ver->>'evidencia',''))='' then v_need:=array_append(v_need,'evidencia'); end if;

  elsif v_req.tipo='federacion' then
    if v_req.perfil_directo_id is null then raise exception 'KOMBAX_DIRECT_PROFILE_REQUIRED'; end if;
    if btrim(coalesce(v_pub->>'pais',''))='' then v_need:=array_append(v_need,'pais'); end if;
    if btrim(coalesce(v_pub->>'territorio',''))='' then v_need:=array_append(v_need,'territorio'); end if;
    if btrim(coalesce(v_pub->>'web_publica','')) !~* '^https://[^[:space:]]+$' then v_need:=array_append(v_need,'web_publica_https'); end if;
    if jsonb_typeof(coalesce(v_pub->'disciplinas','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(v_pub->'disciplinas','[]'::jsonb))<1 then v_need:=array_append(v_need,'disciplinas'); end if;
    if btrim(coalesce(v_ver->>'nombre_legal',''))='' then v_need:=array_append(v_need,'nombre_legal'); end if;
    if btrim(coalesce(v_ver->>'email_oficial',''))='' or position('@' in coalesce(v_ver->>'email_oficial',''))<2 then v_need:=array_append(v_need,'email_oficial'); end if;
    if btrim(coalesce(v_ver->>'registro_entidad',''))='' then v_need:=array_append(v_need,'registro_entidad'); end if;
    if btrim(coalesce(v_ver->>'responsable',''))='' then v_need:=array_append(v_need,'responsable'); end if;
    if btrim(coalesce(v_ver->>'rol_responsable',''))='' then v_need:=array_append(v_need,'rol_responsable'); end if;
    if btrim(coalesce(v_ver->>'evidencia',''))='' then v_need:=array_append(v_need,'evidencia'); end if;

  elsif v_req.tipo='club' then
    perform public.app_kombax_club_payload_validate_v098(v_req.nombre_publico,v_pub,v_ver);
  end if;

  if cardinality(v_need)>0 then raise exception 'KOMBAX_APPLICATION_FIELDS_REQUIRED:%',array_to_string(v_need,','); end if;
  return jsonb_build_object('valid',true,'tipo',v_req.tipo,'documentos',v_docs,'fecha_nacimiento_verificada',v_dob,'edad',v_age,'schema_version',v_req.schema_version);
end $$;
revoke all on function public.app_kombax_application_validate_v072(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_create_club_core_v097(
  p_manager_perfil_id uuid,
  p_nombre_publico text,
  p_datos_publicos jsonb,
  p_datos_verificacion jsonb,
  p_actor_perfil_id uuid
) returns uuid
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_public jsonb:=coalesce(p_datos_publicos,'{}'::jsonb);
  v_verify jsonb:=coalesce(p_datos_verificacion,'{}'::jsonb);
  v_nombre text:=btrim(coalesce(p_nombre_publico,''));
  v_slug text;
  v_club uuid;
  v_disc text;
  v_order smallint:=0;
begin
  perform public.app_kombax_club_payload_validate_v098(p_nombre_publico,v_public,v_verify);
  if p_manager_perfil_id is null or not exists(select 1 from public.perfiles p where p.id=p_manager_perfil_id) then
    raise exception 'KOMBAX_CLUB_MANAGER_PROFILE_REQUIRED';
  end if;
  if p_actor_perfil_id is null or not exists(select 1 from public.perfiles p where p.id=p_actor_perfil_id) then
    raise exception 'KOMBAX_CLUB_ACTOR_PROFILE_REQUIRED';
  end if;
  if char_length(v_nombre)<2 or char_length(v_nombre)>160 then raise exception 'KOMBAX_CLUB_NAME_INVALID'; end if;
  if exists(select 1 from public.clubes c where lower(btrim(c.nombre))=lower(v_nombre)) then raise exception 'KOMBAX_CLUB_ALREADY_EXISTS'; end if;

  v_slug:=public.app_kombax_slug_v043(v_nombre);
  if char_length(coalesce(v_slug,''))<2 then raise exception 'KOMBAX_CLUB_SLUG_INVALID'; end if;
  if exists(select 1 from public.clubes c where c.slug=v_slug) then
    v_slug:=left(v_slug,50)||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,8);
  end if;

  insert into public.clubes(
    nombre,slug,lema,cif,telefono,email,direccion,web,activo,theme_id,branding_actualizado_por,branding_actualizado_en
  ) values(
    v_nombre,
    v_slug,
    left(nullif(btrim(v_public->>'lema'),''),180),
    left(nullif(btrim(coalesce(v_verify->>'cif',v_verify->>'tax_id')),''),40),
    left(nullif(btrim(v_verify->>'telefono'),''),40),
    left(nullif(btrim(coalesce(v_verify->>'email_oficial',v_verify->>'email')),''),254),
    left(nullif(btrim(v_verify->>'direccion'),''),300),
    nullif(btrim(v_public->>'web_publica'),''),
    true,'combat-dark',p_actor_perfil_id,now()
  ) returning id into v_club;

  insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
  values(v_club,p_manager_perfil_id,'direccion',true,true)
  on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=true;

  update public.perfiles_club_publicos pc set
    nombre_publico=v_nombre,
    lema=left(nullif(btrim(v_public->>'lema'),''),180),
    descripcion=left(nullif(btrim(v_public->>'descripcion'),''),1600),
    ciudad=left(nullif(btrim(v_public->>'ciudad'),''),120),
    provincia=left(nullif(btrim(v_public->>'provincia'),''),120),
    pais=left(coalesce(nullif(btrim(v_public->>'pais'),''),'España'),120),
    contacto_publico=left(nullif(btrim(v_public->>'contacto_publico'),''),180),
    web_publica=nullif(btrim(v_public->>'web_publica'),''),
    instagram=left(nullif(btrim(v_public->>'instagram'),''),180),
    tiktok=left(nullif(btrim(v_public->>'tiktok'),''),180),
    youtube=left(nullif(btrim(v_public->>'youtube'),''),180),
    visible=true,moderacion_oculta=false,actualizado_por=p_actor_perfil_id,actualizado_en=now()
  where pc.club_id=v_club;

  if jsonb_typeof(v_public->'disciplinas')='array' then
    for v_disc in
      select distinct btrim(value)
      from jsonb_array_elements_text(v_public->'disciplinas')
      where btrim(value)<>''
      limit 12
    loop
      insert into public.disciplinas(club_id,nombre,activa,orden)
      values(v_club,left(v_disc,120),true,v_order)
      on conflict(club_id,nombre) do nothing;
      v_order:=v_order+1;
    end loop;
  end if;

  insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle)
  values(p_actor_perfil_id,v_club,'kombax.club.provision','club',v_club,
    jsonb_build_object('manager_perfil_id',p_manager_perfil_id,'slug',v_slug,'source','club_onboarding_v097'));

  return v_club;
end;
$$;
revoke all on function public.app_kombax_create_club_core_v097(uuid,text,jsonb,jsonb,uuid) from public,anon,authenticated;

notify pgrst,'reload schema';
commit;
