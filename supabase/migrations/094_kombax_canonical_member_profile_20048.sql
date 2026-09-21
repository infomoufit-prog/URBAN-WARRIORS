-- KOMBAX RC13 build 20048 · canonical Member profile.
-- One public Member identity: KOMBAX Social. The historical perfiles_deportivos
-- table is preserved as legacy input only; it is no longer the current client model.
begin;

alter table public.identidades_sociales
  add column if not exists apodo_deportivo text,
  add column if not exists disciplinas_publicas text,
  add column if not exists experiencia_anos numeric(4,1),
  add column if not exists guardia text,
  add column if not exists tecnica_favorita text,
  add column if not exists especialidad text,
  add column if not exists trayectoria_declarada text,
  add column if not exists objetivos text;

alter table public.identidades_sociales drop constraint if exists identidades_sociales_apodo_deportivo_v094_check;
alter table public.identidades_sociales add constraint identidades_sociales_apodo_deportivo_v094_check check(char_length(coalesce(apodo_deportivo,''))<=60);
alter table public.identidades_sociales drop constraint if exists identidades_sociales_disciplinas_publicas_v094_check;
alter table public.identidades_sociales add constraint identidades_sociales_disciplinas_publicas_v094_check check(char_length(coalesce(disciplinas_publicas,''))<=240);
alter table public.identidades_sociales drop constraint if exists identidades_sociales_experiencia_v094_check;
alter table public.identidades_sociales add constraint identidades_sociales_experiencia_v094_check check(experiencia_anos is null or (experiencia_anos>=0 and experiencia_anos<=80));
alter table public.identidades_sociales drop constraint if exists identidades_sociales_guardia_v094_check;
alter table public.identidades_sociales add constraint identidades_sociales_guardia_v094_check check(char_length(coalesce(guardia,''))<=40);
alter table public.identidades_sociales drop constraint if exists identidades_sociales_tecnica_v094_check;
alter table public.identidades_sociales add constraint identidades_sociales_tecnica_v094_check check(char_length(coalesce(tecnica_favorita,''))<=120);
alter table public.identidades_sociales drop constraint if exists identidades_sociales_especialidad_v094_check;
alter table public.identidades_sociales add constraint identidades_sociales_especialidad_v094_check check(char_length(coalesce(especialidad,''))<=120);
alter table public.identidades_sociales drop constraint if exists identidades_sociales_trayectoria_v094_check;
alter table public.identidades_sociales add constraint identidades_sociales_trayectoria_v094_check check(char_length(coalesce(trayectoria_declarada,''))<=1200);
alter table public.identidades_sociales drop constraint if exists identidades_sociales_objetivos_v094_check;
alter table public.identidades_sociales add constraint identidades_sociales_objetivos_v094_check check(char_length(coalesce(objetivos,''))<=800);

-- Conservative backfill: only fill empty Social fields. Never overwrite newer Social data.
update public.identidades_sociales i set
  apodo_deportivo=coalesce(nullif(i.apodo_deportivo,''),nullif(pd.apodo,'')),
  bio_publica=coalesce(nullif(i.bio_publica,''),nullif(pd.presentacion,'')),
  experiencia_anos=coalesce(i.experiencia_anos,pd.experiencia_anos),
  guardia=coalesce(nullif(i.guardia,''),nullif(pd.guardia,'')),
  tecnica_favorita=coalesce(nullif(i.tecnica_favorita,''),nullif(pd.tecnica_favorita,'')),
  especialidad=coalesce(nullif(i.especialidad,''),nullif(pd.especialidad,'')),
  trayectoria_declarada=coalesce(nullif(i.trayectoria_declarada,''),nullif(pd.competiciones_logros,'')),
  objetivos=coalesce(nullif(i.objetivos,''),nullif(pd.objetivos,'')),
  actualizado_en=case when
    (i.apodo_deportivo is null and nullif(pd.apodo,'') is not null) or
    (i.bio_publica is null and nullif(pd.presentacion,'') is not null) or
    (i.experiencia_anos is null and pd.experiencia_anos is not null) or
    (i.guardia is null and nullif(pd.guardia,'') is not null) or
    (i.tecnica_favorita is null and nullif(pd.tecnica_favorita,'') is not null) or
    (i.especialidad is null and nullif(pd.especialidad,'') is not null) or
    (i.trayectoria_declarada is null and nullif(pd.competiciones_logros,'') is not null) or
    (i.objetivos is null and nullif(pd.objetivos,'') is not null)
    then now() else i.actualizado_en end
from public.perfiles_deportivos pd
where pd.club_id=i.club_origen_id and pd.socio_id=i.socio_origen_id;

-- Current synchronizer no longer reads perfiles_deportivos. Member is never badge-verified
-- merely for being a club member, and promotion to Competitor keeps the same Social row.
create or replace function public.app_kombax_social_sync_miembro_v041()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_comp uuid;v_socio public.socios;v_adulto boolean:=false;
begin
  select d.id into v_comp from public.perfiles_kombax_directos d
  where d.tipo='competidor' and d.origen_identidad_social_id=new.id order by d.creado_en limit 1;
  if v_comp is not null then perform public.app_kombax_social_switch_competitor_v072(v_comp); return new; end if;
  select * into v_socio from public.socios s where s.id=new.socio_origen_id and s.club_id=new.club_origen_id;
  v_adulto:=v_socio.fecha_nacimiento is not null and extract(year from age(current_date,v_socio.fecha_nacimiento))>=18;
  insert into public.kombax_social_perfiles(sujeto_tipo,identidad_social_id,slug,nombre_publico,bio,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
  values('miembro',new.id,new.slug,new.nombre_publico,new.bio_publica,false,new.estado='activa',new.estado='activa',new.estado='activa' and v_adulto,
    case new.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end)
  on conflict(identidad_social_id) where sujeto_tipo='miembro' do update set
    slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,verificado=false,
    visible=excluded.visible,publicar_habilitado=excluded.publicar_habilitado,
    contacto_habilitado=excluded.contacto_habilitado,estado=excluded.estado,actualizado_en=now();
  return new;
end $$;
revoke all on function public.app_kombax_social_sync_miembro_v041() from public,anon,authenticated;

-- 20.048 identity gateway. Member activation/profile editing are implemented directly
-- so the current client no longer depends on the historical sports-profile table.
create or replace function public.app_kombax_identity_mutate_v094(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;
  v_club uuid;v_socio public.socios;v_identity public.identidades_sociales;v_texto public.textos_legales;v_min integer:=14;v_age integer;v_exp numeric;
  v_bio text;v_apodo text;v_disc text;v_guardia text;v_tecnica text;v_especialidad text;v_trayectoria text;v_objetivos text;
begin
  if p_operation not in ('kombax.identity.member.activate','kombax.identity.member.profile.update') then
    return public.app_kombax_identity_mutate_v065(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid;exception when others then raise exception 'KOMBAX_CLUB_ID_INVALID';end;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation);
  end if;

  if p_operation='kombax.identity.member.activate' then
    if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MEMBERSHIP_REQUIRED';end if;
    select * into v_socio from public.socios where club_id=v_club and perfil_id=v_uid and estado='activo' order by creado_en desc limit 1;
    if v_socio.id is null or v_socio.fecha_nacimiento is null then raise exception 'KOMBAX_SOCIAL_AGE_VERIFICATION_REQUIRED';end if;
    v_age:=extract(year from age(current_date,v_socio.fecha_nacimiento))::integer;
    begin v_min:=public.app_edad_min_comunidad_general_v036(v_club);exception when others then v_min:=14;end;
    if v_age<v_min then raise exception 'KOMBAX_SOCIAL_MINIMUM_AGE';end if;
    if coalesce((v_payload->>'acepta_normas')::boolean,false) is not true or coalesce((v_payload->>'acepta_privacidad')::boolean,false) is not true then raise exception 'KOMBAX_SOCIAL_CONSENT_REQUIRED';end if;
    select * into v_identity from public.identidades_sociales where perfil_id=v_uid for update;
    if v_identity.id is not null and v_identity.estado in ('suspendida','cerrada') then raise exception 'KOMBAX_SOCIAL_REACTIVATION_REQUIRES_REVIEW';end if;
    select * into v_texto from public.textos_legales where club_id=v_club and tipo='comunidad_general' and vigente order by creado_en desc limit 1;
    if v_texto.id is null then raise exception 'KOMBAX_SOCIAL_RULES_UNAVAILABLE';end if;
    insert into public.aceptaciones_legales(club_id,perfil_id,socio_id,texto_legal_id,tipo,version,aceptado,aceptado_en,revocado_en,user_agent)
    values(v_club,v_uid,v_socio.id,v_texto.id,'comunidad_general',v_texto.version,true,now(),null,left(coalesce(v_payload->>'user_agent',''),500))
    on conflict do nothing;
    insert into public.identidades_sociales(perfil_id,club_origen_id,socio_origen_id,tipo,slug,nombre_publico,estado,version_normas,activada_en,actualizado_en)
    values(v_uid,v_club,v_socio.id,'miembro','miembro-'||replace(v_uid::text,'-',''),trim(concat_ws(' ',v_socio.nombre,v_socio.apellidos)),'activa',v_texto.version,now(),now())
    on conflict(perfil_id) do update set club_origen_id=excluded.club_origen_id,socio_origen_id=excluded.socio_origen_id,nombre_publico=excluded.nombre_publico,
      estado='activa',version_normas=excluded.version_normas,suspendida_en=null,suspension_motivo=null,actualizado_en=now()
    returning * into v_identity;
    v_result:=jsonb_build_object('identidad_social_id',v_identity.id,'status','activa','rules_version',v_texto.version);
  else
    select * into v_identity from public.identidades_sociales where perfil_id=v_uid for update;
    if v_identity.id is null or v_identity.estado<>'activa' then raise exception 'KOMBAX_MEMBER_SOCIAL_IDENTITY_REQUIRED';end if;
    if v_club is not null and v_identity.club_origen_id<>v_club then raise exception 'KOMBAX_MEMBER_SOCIAL_CLUB_MISMATCH';end if;
    v_bio:=nullif(btrim(coalesce(v_payload->>'bio_publica','')),'');
    v_apodo:=nullif(btrim(coalesce(v_payload->>'apodo_deportivo','')),'');
    v_disc:=nullif(btrim(coalesce(v_payload->>'disciplinas_publicas','')),'');
    v_guardia:=nullif(btrim(coalesce(v_payload->>'guardia','')),'');
    v_tecnica:=nullif(btrim(coalesce(v_payload->>'tecnica_favorita','')),'');
    v_especialidad:=nullif(btrim(coalesce(v_payload->>'especialidad','')),'');
    v_trayectoria:=nullif(btrim(coalesce(v_payload->>'trayectoria_declarada','')),'');
    v_objetivos:=nullif(btrim(coalesce(v_payload->>'objetivos','')),'');
    begin v_exp:=nullif(v_payload->>'experiencia_anos','')::numeric;exception when others then raise exception 'KOMBAX_MEMBER_EXPERIENCE_INVALID';end;
    if char_length(coalesce(v_bio,''))>800 then raise exception 'KOMBAX_MEMBER_SOCIAL_BIO_TOO_LONG';end if;
    if char_length(coalesce(v_apodo,''))>60 or char_length(coalesce(v_disc,''))>240 or char_length(coalesce(v_guardia,''))>40 or char_length(coalesce(v_tecnica,''))>120 or char_length(coalesce(v_especialidad,''))>120 or char_length(coalesce(v_trayectoria,''))>1200 or char_length(coalesce(v_objetivos,''))>800 then raise exception 'KOMBAX_MEMBER_PUBLIC_SPORTS_FIELDS_TOO_LONG';end if;
    if v_exp is not null and (v_exp<0 or v_exp>80) then raise exception 'KOMBAX_MEMBER_EXPERIENCE_INVALID';end if;
    update public.identidades_sociales set bio_publica=v_bio,apodo_deportivo=v_apodo,disciplinas_publicas=v_disc,experiencia_anos=v_exp,
      guardia=v_guardia,tecnica_favorita=v_tecnica,especialidad=v_especialidad,trayectoria_declarada=v_trayectoria,objetivos=v_objetivos,actualizado_en=now()
    where id=v_identity.id returning * into v_identity;
    insert into public.kombax_actor_audit(actor_perfil_id,public_social_id,club_id,accion,objeto_tipo,objeto_id,detalle)
      select v_uid,sp.id,v_identity.club_origen_id,'social.member.profile.update','social_profile',sp.id,
        jsonb_build_object('bio_updated',true,'sports_profile_canonical',true)
      from public.kombax_social_perfiles sp where sp.sujeto_tipo='miembro' and sp.identidad_social_id=v_identity.id;
    v_result:=jsonb_build_object('identidad_social_id',v_identity.id,'bio_publica',v_identity.bio_publica,'sports_profile_canonical',true);
  end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_identity_mutate_v094(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_identity_mutate_v094(text,jsonb,uuid) to authenticated;

-- Enrich the same public Social profile; no second public profile is created.
create or replace function public.app_kombax_perfil_publico_v094(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;v_sports jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  v:=public.app_kombax_perfil_publico_v083(p_social_id);
  if v is null then return null;end if;
  if coalesce(v->>'perfil_tipo',v->>'sujeto_tipo','')='miembro' then
    select jsonb_strip_nulls(jsonb_build_object(
      'apodo_deportivo',i.apodo_deportivo,'disciplinas_publicas',i.disciplinas_publicas,'experiencia_anos',i.experiencia_anos,
      'guardia',i.guardia,'tecnica_favorita',i.tecnica_favorita,'especialidad',i.especialidad,
      'trayectoria_declarada',i.trayectoria_declarada,'objetivos',i.objetivos
    )) into v_sports
    from public.kombax_social_perfiles sp join public.identidades_sociales i on i.id=sp.identidad_social_id
    where sp.id=p_social_id and sp.sujeto_tipo='miembro';
    v:=jsonb_set(v,'{sports}',coalesce(v_sports,'{}'::jsonb),true);
  end if;
  return v-'relations';
end $$;
revoke all on function public.app_kombax_perfil_publico_v094(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v094(uuid) to authenticated;

comment on table public.perfiles_deportivos is 'LEGACY 20.048: historical club sports profile. Preserved for compatibility/migration; current KOMBAX client uses the canonical Social Member profile.';

notify pgrst,'reload schema';
commit;
