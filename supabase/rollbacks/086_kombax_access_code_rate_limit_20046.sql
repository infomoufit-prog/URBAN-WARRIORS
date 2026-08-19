-- Emergency rollback to the 060 access-code behavior. Rate-limit tables are retained for audit evidence.
begin;
create or replace function public.app_kombax_codigo_validar_v060(p_club_slug text,p_tipo text,p_codigo text)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare t text:=lower(trim(coalesce(p_tipo,''))); c text:=trim(coalesce(p_codigo,'')); club public.clubes; k public.kombax_codigos_acceso_club; ok boolean:=false; ver integer;
begin
  if t not in ('alumnos','equipo') or c !~ '^[0-9]{4,5}$' then return jsonb_build_object('valid',false);end if;
  select * into club from public.clubes x where lower(x.slug)=lower(trim(coalesce(p_club_slug,''))) and x.activo limit 1;
  if club.id is null then return jsonb_build_object('valid',false);end if;
  select * into k from public.kombax_codigos_acceso_club where club_id=club.id;
  if k.club_id is null then return jsonb_build_object('valid',false);end if;
  if t='alumnos' then ok:=c=k.codigo_alumnos;ver:=k.alumnos_version;else ok:=c=k.codigo_equipo;ver:=k.equipo_version;end if;
  if not ok then return jsonb_build_object('valid',false);end if;
  return jsonb_build_object('valid',true,'tipo',t,'club_id',club.id,'club_slug',club.slug,'club_nombre',club.nombre,'version',ver);
end $$;
revoke all on function public.app_kombax_codigo_validar_v060(text,text,text) from public;
grant execute on function public.app_kombax_codigo_validar_v060(text,text,text) to anon,authenticated,service_role;

create or replace function public.app_kombax_equipo_solicitar_v060(p_club_slug text,p_codigo text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare uid uuid:=auth.uid(); chk jsonb; cid uuid; ver integer; row public.kombax_solicitudes_equipo_club; mail text:=lower(coalesce(auth.jwt()->>'email',''));
begin
  if uid is null then raise exception 'AUTH_REQUIRED';end if;
  chk:=public.app_kombax_codigo_validar_v060(p_club_slug,'equipo',p_codigo);
  if coalesce((chk->>'valid')::boolean,false) is not true then raise exception 'Código de equipo no válido';end if;
  cid:=(chk->>'club_id')::uuid;ver:=(chk->>'version')::integer;
  if exists(select 1 from public.miembros_club m where m.club_id=cid and m.perfil_id=uid and m.activo) then raise exception 'Tu cuenta ya pertenece a este club';end if;
  insert into public.perfiles(id,nombre,apellidos) values(uid,coalesce(nullif(auth.jwt()->'user_metadata'->>'nombre',''),split_part(mail,'@',1)),coalesce(auth.jwt()->'user_metadata'->>'apellidos','')) on conflict(id) do nothing;
  insert into public.kombax_solicitudes_equipo_club(club_id,perfil_id,email,estado,codigo_version,creado_en,actualizado_en,revisado_en,revisado_por,rol_asignado,coordinacion,nota_revision)
  values(cid,uid,mail,'pendiente',ver,now(),now(),null,null,null,false,null)
  on conflict(club_id,perfil_id) do update set email=excluded.email,estado='pendiente',codigo_version=excluded.codigo_version,actualizado_en=now(),revisado_en=null,revisado_por=null,rol_asignado=null,coordinacion=false,nota_revision=null
  returning * into row;
  return jsonb_build_object('id',row.id,'club_id',row.club_id,'club_slug',chk->>'club_slug','club_nombre',chk->>'club_nombre','estado',row.estado,'creado_en',row.creado_en);
end $$;
revoke all on function public.app_kombax_equipo_solicitar_v060(text,text) from public,anon;
grant execute on function public.app_kombax_equipo_solicitar_v060(text,text) to authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare payload jsonb:=coalesce(p_payload,'{}'::jsonb); code text:=trim(coalesce(payload->>'invite_code','')); slug text:=trim(coalesce(payload->>'club_slug','')); chk jsonb; result jsonb;
begin
  if p_operation in ('invitacion.crear','invitacion.aceptar') then raise exception 'INVITATION_FLOW_DEPRECATED: usa los códigos permanentes del club';end if;
  if p_operation='cuenta.registrar' and code<>'' then
    chk:=public.app_kombax_codigo_validar_v060(slug,'alumnos',code);
    if coalesce((chk->>'valid')::boolean,false) is not true then raise exception 'Código de alumnos/familias no válido para este club';end if;
    payload:=jsonb_set(payload,'{invite_code}','null'::jsonb,true);
    result:=public.app_mutate_v160_pre_access_codes_060(p_operation,payload,p_request_id);
    result:=jsonb_set(result,'{data,club_access_code}',jsonb_build_object('tipo','alumnos','version',(chk->>'version')::integer),true);
    update public.app_mutation_requests set result=result where request_id=p_request_id;
    return result;
  end if;
  return public.app_mutate_v160_pre_access_codes_060(p_operation,p_payload,p_request_id);
end $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;
revoke execute on function public.app_kombax_codigo_validar_seguro_v086(text,text,text) from authenticated;
notify pgrst,'reload schema';
commit;
