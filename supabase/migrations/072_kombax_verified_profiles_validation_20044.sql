-- KOMBAX RC13 build 20044 · 072 · kombax verified profiles validation

begin;

-- ---------------------------------------------------------------------------
-- 1. Validación canónica de solicitudes. Solo Club/Competidor/Marca/Federación.
-- ---------------------------------------------------------------------------
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
    if btrim(coalesce(v_pub->>'ubicacion',''))='' then v_need:=array_append(v_need,'ubicacion'); end if;
    if jsonb_typeof(coalesce(v_pub->'disciplinas','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(v_pub->'disciplinas','[]'::jsonb))<1 then v_need:=array_append(v_need,'disciplinas'); end if;
    if btrim(coalesce(v_ver->>'nombre_legal',''))='' then v_need:=array_append(v_need,'nombre_legal'); end if;
    if btrim(coalesce(v_ver->>'email_oficial',''))='' or position('@' in coalesce(v_ver->>'email_oficial',''))<2 then v_need:=array_append(v_need,'email_oficial'); end if;
    if btrim(coalesce(v_ver->>'responsable',''))='' then v_need:=array_append(v_need,'responsable'); end if;
    if btrim(coalesce(v_ver->>'rol_responsable',''))='' then v_need:=array_append(v_need,'rol_responsable'); end if;
    if btrim(coalesce(v_ver->>'evidencia',''))='' then v_need:=array_append(v_need,'evidencia'); end if;
  end if;

  if cardinality(v_need)>0 then raise exception 'KOMBAX_APPLICATION_FIELDS_REQUIRED:%',array_to_string(v_need,','); end if;
  return jsonb_build_object('valid',true,'tipo',v_req.tipo,'documentos',v_docs,'fecha_nacimiento_verificada',v_dob,'edad',v_age,'schema_version',v_req.schema_version);
end $$;
revoke all on function public.app_kombax_application_validate_v072(uuid) from public,anon,authenticated;

notify pgrst,'reload schema';
commit;
