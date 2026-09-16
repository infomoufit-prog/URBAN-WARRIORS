-- KOMBAX 20.101 R40 · Social network visibility + club exclusions.
-- Mirrors live migration 20260904172146 · kombax_social_network_visibility_r40.
-- Content visibility never breaks network relationships, messaging or event participation.
begin;

alter table public.kombax_social_publicaciones drop constraint if exists kombax_social_publicaciones_audiencia_check;
alter table public.kombax_social_publicaciones add constraint kombax_social_publicaciones_audiencia_check
check (audiencia in ('publica','club','federacion','clubes_federacion','red','clubes_seleccionados','kombax_excepto'));

alter table public.kombax_social_publicaciones drop constraint if exists kombax_social_publicaciones_audiencia_target_check;
alter table public.kombax_social_publicaciones add constraint kombax_social_publicaciones_audiencia_target_check check(
  (audiencia in ('publica','red','clubes_seleccionados','kombax_excepto') and audiencia_club_id is null and audiencia_federacion_social_id is null)
  or (audiencia='club' and audiencia_club_id is not null and audiencia_federacion_social_id is null)
  or (audiencia in ('federacion','clubes_federacion') and audiencia_club_id is null and audiencia_federacion_social_id is not null)
);

create table if not exists public.kombax_social_post_visibility_clubs_v235(
  post_id uuid not null references public.kombax_social_publicaciones(id) on delete cascade,
  club_id uuid not null references public.clubes(id) on delete cascade,
  rule text not null check(rule in ('include','exclude')),
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  primary key(post_id,club_id,rule)
);
create index if not exists idx_kombax_social_visibility_clubs_v235_club on public.kombax_social_post_visibility_clubs_v235(club_id,rule,post_id);
create index if not exists idx_kombax_social_visibility_clubs_v235_created_by on public.kombax_social_post_visibility_clubs_v235(created_by) where created_by is not null;
alter table public.kombax_social_post_visibility_clubs_v235 enable row level security;
drop policy if exists kombax_social_post_visibility_clubs_v235_deny_direct on public.kombax_social_post_visibility_clubs_v235;
create policy kombax_social_post_visibility_clubs_v235_deny_direct on public.kombax_social_post_visibility_clubs_v235 for all using(false) with check(false);
revoke all on table public.kombax_social_post_visibility_clubs_v235 from public,anon,authenticated;

create or replace function public.app_kombax_social_usuario_controla_social_v235(p_social_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(
    select 1
    from public.kombax_social_perfiles sp
    left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and (
      (sp.sujeto_tipo='miembro' and exists(
        select 1 from public.identidades_sociales i where i.id=sp.identidad_social_id and i.perfil_id=auth.uid() and i.estado='activa'
      ))
      or (sp.sujeto_tipo='club' and public.app_kombax_social_usuario_pertenece_club_v083(sp.club_id))
      or (sp.sujeto_tipo='perfil_directo' and d.id is not null and (d.perfil_id=auth.uid() or public.app_kombax_puede_gestionar_perfil_v070(d.id,'social')))
    )
  );
$$;
revoke all on function public.app_kombax_social_usuario_controla_social_v235(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_social_usuario_en_club_rules_v235(p_post_id uuid,p_rule text)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(
    select 1 from public.kombax_social_post_visibility_clubs_v235 r
    where r.post_id=p_post_id and r.rule=p_rule and public.app_kombax_social_usuario_pertenece_club_v083(r.club_id)
  );
$$;
revoke all on function public.app_kombax_social_usuario_en_club_rules_v235(uuid,text) from public,anon,authenticated;

create or replace function public.app_kombax_social_audiencias_v083(p_autor_social_id uuid)
returns table(audiencia text,target_social_id uuid,target_club_id uuid,label text,descripcion text,predeterminada boolean)
language plpgsql stable security definer set search_path='' as $$
declare v_type text;v_club uuid;v_fed record;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_kombax_social_puede_actuar_v051(p_autor_social_id) then raise exception 'KOMBAX_AUDIENCE_ACTOR_FORBIDDEN';end if;
  v_type:=public.app_kombax_social_tipo_v051(p_autor_social_id);
  v_club:=public.app_kombax_social_actor_club_v083(p_autor_social_id);
  return query select 'publica'::text,null::uuid,null::uuid,'Todo KOMBAX'::text,'Visible para toda la comunidad KOMBAX Social.'::text,true;
  return query select 'red'::text,null::uuid,null::uuid,'Mi red'::text,'Solo perfiles conectados contigo mediante una relación aceptada.'::text,false;
  return query select 'clubes_seleccionados'::text,null::uuid,null::uuid,'Clubes seleccionados…'::text,'Elige uno o varios clubes que podrán ver esta publicación.'::text,false;
  return query select 'kombax_excepto'::text,null::uuid,null::uuid,'Todo KOMBAX excepto clubes…'::text,'Visible en KOMBAX salvo para los clubes que decidas excluir.'::text,false;
  if v_type in ('miembro','competidor','club') and v_club is not null then
    return query select 'club'::text,null::uuid,v_club,'Solo mi club'::text,'Visible únicamente para cuentas vinculadas a tu club.'::text,false;
  end if;
  if v_type='federacion' then
    return query select 'federacion'::text,p_autor_social_id,null::uuid,'Solo afiliados a mi federación'::text,'Visible para miembros y equipo de clubes afiliados.'::text,false;
    return query select 'clubes_federacion'::text,p_autor_social_id,null::uuid,'Solo clubes afiliados'::text,'Circular dirigida únicamente a responsables autorizados de clubes afiliados.'::text,false;
  elsif v_club is not null then
    for v_fed in
      select distinct f.id,f.nombre_publico
      from public.kombax_relaciones r
      join public.kombax_social_perfiles clubsp on clubsp.id=public.app_kombax_social_club_social_v083(v_club)
      join public.kombax_social_perfiles f on f.id=case when r.origen_social_id=clubsp.id then r.destino_social_id else r.origen_social_id end
      join public.perfiles_kombax_directos d on d.id=f.perfil_directo_id and d.tipo='federacion'
      where r.tipo='club_federacion' and r.estado='confirmed' and (r.origen_social_id=clubsp.id or r.destino_social_id=clubsp.id) and f.estado='activo' and f.visible
      order by f.nombre_publico
    loop
      return query select 'federacion'::text,v_fed.id,null::uuid,('Solo afiliados · '||v_fed.nombre_publico)::text,'Visible únicamente para la comunidad de clubes afiliados a esta federación.'::text,false;
    end loop;
  end if;
end $$;
revoke all on function public.app_kombax_social_audiencias_v083(uuid) from public,anon;
grant execute on function public.app_kombax_social_audiencias_v083(uuid) to authenticated;

create or replace function public.app_kombax_social_puede_ver_publicacion_v083(p_publicacion_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_post public.kombax_social_publicaciones;v_author public.kombax_social_perfiles;v_allowed boolean:=false;
begin
  if auth.uid() is null then return false;end if;
  select * into v_post from public.kombax_social_publicaciones where id=p_publicacion_id and estado='activa';
  if v_post.id is null then return false;end if;
  select * into v_author from public.kombax_social_perfiles where id=v_post.autor_perfil_id and estado='activo' and visible;
  if v_author.id is null then return false;end if;
  if public.app_kombax_social_puede_actuar_v051(v_author.id) then return true;end if;
  if v_post.audiencia='publica' then v_allowed:=true;
  elsif v_post.audiencia='club' then v_allowed:=public.app_kombax_social_usuario_pertenece_club_v083(v_post.audiencia_club_id);
  elsif v_post.audiencia='federacion' then v_allowed:=public.app_kombax_social_usuario_afiliado_federacion_v083(v_post.audiencia_federacion_social_id,false);
  elsif v_post.audiencia='clubes_federacion' then v_allowed:=public.app_kombax_social_usuario_afiliado_federacion_v083(v_post.audiencia_federacion_social_id,true);
  elsif v_post.audiencia='clubes_seleccionados' then v_allowed:=public.app_kombax_social_usuario_en_club_rules_v235(v_post.id,'include');
  elsif v_post.audiencia='kombax_excepto' then v_allowed:=true;
  elsif v_post.audiencia='red' then
    select exists(
      select 1 from public.kombax_relaciones r
      where r.estado='confirmed' and (r.origen_social_id=v_author.id or r.destino_social_id=v_author.id)
        and public.app_kombax_social_usuario_controla_social_v235(case when r.origen_social_id=v_author.id then r.destino_social_id else r.origen_social_id end)
    ) into v_allowed;
  end if;
  if not coalesce(v_allowed,false) then return false;end if;
  if public.app_kombax_social_usuario_en_club_rules_v235(v_post.id,'exclude') then return false;end if;
  return true;
end $$;
revoke all on function public.app_kombax_social_puede_ver_publicacion_v083(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_social_audiencia_label_v083(p_publicacion_id uuid)
returns text language sql stable security definer set search_path='' as $$
  select case p.audiencia
    when 'publica' then case when exists(select 1 from public.kombax_social_post_visibility_clubs_v235 r where r.post_id=p.id and r.rule='exclude') then 'Todo KOMBAX · con exclusiones' else 'Todo KOMBAX' end
    when 'red' then 'Mi red' when 'club' then 'Solo mi club' when 'federacion' then 'Solo federación'
    when 'clubes_federacion' then 'Solo clubes afiliados' when 'clubes_seleccionados' then 'Clubes seleccionados'
    when 'kombax_excepto' then 'Todo KOMBAX · con exclusiones' else 'Restringida' end
  from public.kombax_social_publicaciones p where p.id=p_publicacion_id;
$$;
revoke all on function public.app_kombax_social_audiencia_label_v083(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_social_mutate_v083_pre_media_v085(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_result jsonb;v_actor uuid;v_post_id uuid;v_audience text;v_target_social uuid;v_target_club uuid;v_match boolean;
  v_include jsonb:=case when jsonb_typeof(p_payload->'audiencia_club_ids')='array' then p_payload->'audiencia_club_ids' else '[]'::jsonb end;
  v_exclude jsonb:=case when jsonb_typeof(p_payload->'audiencia_excluded_club_ids')='array' then p_payload->'audiencia_excluded_club_ids' else '[]'::jsonb end;
  v_item text;v_club uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if p_operation='kombax.social.publicar' then
    begin v_actor:=(v_payload->>'autor_perfil_id')::uuid;v_target_social:=nullif(v_payload->>'audiencia_federacion_social_id','')::uuid;v_target_club:=nullif(v_payload->>'audiencia_club_id','')::uuid;
    exception when others then raise exception 'KOMBAX_POST_AUDIENCE_INVALID';end;
    v_audience:=lower(coalesce(nullif(v_payload->>'audiencia',''),'publica'));
    select exists(select 1 from public.app_kombax_social_audiencias_v083(v_actor) a where a.audiencia=v_audience and a.target_social_id is not distinct from v_target_social and a.target_club_id is not distinct from v_target_club) into v_match;
    if not v_match then raise exception 'KOMBAX_POST_AUDIENCE_NOT_ALLOWED';end if;
    if jsonb_array_length(v_include)>50 or jsonb_array_length(v_exclude)>50 then raise exception 'KOMBAX_POST_AUDIENCE_CLUB_LIMIT_50';end if;
    if v_audience='clubes_seleccionados' and jsonb_array_length(v_include)<1 then raise exception 'KOMBAX_POST_AUDIENCE_CLUB_REQUIRED';end if;
    if v_audience='kombax_excepto' and jsonb_array_length(v_exclude)<1 then raise exception 'KOMBAX_POST_AUDIENCE_EXCLUSION_REQUIRED';end if;
    if v_audience<>'clubes_seleccionados' then v_include:='[]'::jsonb;end if;
    if v_audience<>'kombax_excepto' then v_exclude:='[]'::jsonb;end if;
    v_result:=public.app_kombax_social_mutate_v067(p_operation,p_payload,p_request_id);
    begin v_post_id:=(v_result->'data'->>'id')::uuid;exception when others then raise exception 'KOMBAX_POST_RESULT_INVALID';end;
    for v_item in select distinct value from jsonb_array_elements_text(v_include) loop
      begin v_club:=v_item::uuid;exception when others then raise exception 'KOMBAX_POST_AUDIENCE_CLUB_INVALID';end;
      if not exists(select 1 from public.clubes c where c.id=v_club and c.activo) then raise exception 'KOMBAX_POST_AUDIENCE_CLUB_NOT_FOUND';end if;
      insert into public.kombax_social_post_visibility_clubs_v235(post_id,club_id,rule,created_by) values(v_post_id,v_club,'include',auth.uid()) on conflict do nothing;
    end loop;
    for v_item in select distinct value from jsonb_array_elements_text(v_exclude) loop
      begin v_club:=v_item::uuid;exception when others then raise exception 'KOMBAX_POST_AUDIENCE_CLUB_INVALID';end;
      if not exists(select 1 from public.clubes c where c.id=v_club and c.activo) then raise exception 'KOMBAX_POST_AUDIENCE_CLUB_NOT_FOUND';end if;
      insert into public.kombax_social_post_visibility_clubs_v235(post_id,club_id,rule,created_by) values(v_post_id,v_club,'exclude',auth.uid()) on conflict do nothing;
    end loop;
    update public.kombax_social_publicaciones set audiencia=v_audience,audiencia_club_id=v_target_club,audiencia_federacion_social_id=v_target_social,actualizado_en=now() where id=v_post_id;
    v_result:=jsonb_set(v_result,'{data,audiencia}',to_jsonb(v_audience),true);
    v_result:=jsonb_set(v_result,'{data,audiencia_club_id}',coalesce(to_jsonb(v_target_club),'null'::jsonb),true);
    v_result:=jsonb_set(v_result,'{data,audiencia_federacion_social_id}',coalesce(to_jsonb(v_target_social),'null'::jsonb),true);
    update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id and user_id=auth.uid();
    return v_result;
  end if;
  if p_operation in ('kombax.social.like','kombax.social.guardar','kombax.social.comentar') then
    begin v_post_id:=(v_payload->>'publicacion_id')::uuid;exception when others then raise exception 'KOMBAX_POST_ID_INVALID';end;
    if not public.app_kombax_social_puede_ver_publicacion_v083(v_post_id) then raise exception 'KOMBAX_POST_AUDIENCE_FORBIDDEN';end if;
  elsif p_operation='kombax.social.denunciar' and lower(coalesce(v_payload->>'objetivo_tipo',''))='publicacion' then
    begin v_post_id:=(v_payload->>'objetivo_id')::uuid;exception when others then raise exception 'KOMBAX_POST_ID_INVALID';end;
    if not public.app_kombax_social_puede_ver_publicacion_v083(v_post_id) then raise exception 'KOMBAX_POST_AUDIENCE_FORBIDDEN';end if;
  end if;
  return public.app_kombax_social_mutate_v067(p_operation,p_payload,p_request_id);
end $$;
revoke all on function public.app_kombax_social_mutate_v083_pre_media_v085(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v083_pre_media_v085(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
