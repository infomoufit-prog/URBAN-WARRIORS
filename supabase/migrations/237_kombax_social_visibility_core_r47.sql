-- KOMBAX 20.101 R47 · Social relevance preference + advanced post visibility.
-- Replaces user-side "hide post" UX with reversible Me interesa / No me interesa signals.
-- Adds explicit post audiences for selected social profiles and profile types.
begin;

-- R46 hide rows are cleared so a prior hide never silently removes content in R47.
delete from public.kombax_social_ocultados_usuario;
comment on table public.kombax_social_ocultados_usuario is 'Deprecated R46 compatibility table. R47 does not use it for feed filtering.';

create table if not exists public.kombax_social_preferencias_usuario_v237(
  user_id uuid not null references auth.users(id) on delete cascade,
  publicacion_id uuid not null references public.kombax_social_publicaciones(id) on delete cascade,
  valor smallint not null check(valor in (-1,1)),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  primary key(user_id,publicacion_id)
);
create index if not exists idx_kombax_social_pref_post_v237 on public.kombax_social_preferencias_usuario_v237(publicacion_id,valor,user_id);
alter table public.kombax_social_preferencias_usuario_v237 enable row level security;
revoke all on public.kombax_social_preferencias_usuario_v237 from public,anon,authenticated;

create table if not exists public.kombax_social_post_visibility_profiles_v237(
  post_id uuid not null references public.kombax_social_publicaciones(id) on delete cascade,
  social_id uuid not null references public.kombax_social_perfiles(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  primary key(post_id,social_id)
);
create index if not exists idx_kombax_social_vis_profiles_social_v237 on public.kombax_social_post_visibility_profiles_v237(social_id,post_id);
alter table public.kombax_social_post_visibility_profiles_v237 enable row level security;
revoke all on public.kombax_social_post_visibility_profiles_v237 from public,anon,authenticated;

create table if not exists public.kombax_social_post_visibility_types_v237(
  post_id uuid not null references public.kombax_social_publicaciones(id) on delete cascade,
  profile_type text not null check(profile_type in ('miembro','club','competidor','marca','federacion','profesional','espectador')),
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  primary key(post_id,profile_type)
);
create index if not exists idx_kombax_social_vis_types_type_v237 on public.kombax_social_post_visibility_types_v237(profile_type,post_id);
alter table public.kombax_social_post_visibility_types_v237 enable row level security;
revoke all on public.kombax_social_post_visibility_types_v237 from public,anon,authenticated;

alter table public.kombax_social_publicaciones drop constraint if exists kombax_social_publicaciones_audiencia_check;
alter table public.kombax_social_publicaciones add constraint kombax_social_publicaciones_audiencia_check
check (audiencia in ('publica','club','federacion','clubes_federacion','red','clubes_seleccionados','kombax_excepto','perfiles_seleccionados','tipos_perfil'));

alter table public.kombax_social_publicaciones drop constraint if exists kombax_social_publicaciones_audiencia_target_check;
alter table public.kombax_social_publicaciones add constraint kombax_social_publicaciones_audiencia_target_check check(
  (audiencia in ('publica','red','clubes_seleccionados','kombax_excepto','perfiles_seleccionados','tipos_perfil') and audiencia_club_id is null and audiencia_federacion_social_id is null)
  or (audiencia='club' and audiencia_club_id is not null and audiencia_federacion_social_id is null)
  or (audiencia in ('federacion','clubes_federacion') and audiencia_club_id is null and audiencia_federacion_social_id is not null)
);

create or replace function public.app_kombax_social_usuario_en_perfiles_v237(p_post_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(
    select 1 from public.kombax_social_post_visibility_profiles_v237 r
    where r.post_id=p_post_id and public.app_kombax_social_usuario_controla_social_v235(r.social_id)
  );
$$;
revoke all on function public.app_kombax_social_usuario_en_perfiles_v237(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_social_usuario_en_tipos_v237(p_post_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(
    select 1
    from public.kombax_social_post_visibility_types_v237 r
    join public.kombax_social_perfiles sp on public.app_kombax_social_tipo_v051(sp.id)=r.profile_type
    where r.post_id=p_post_id and sp.visible and sp.estado='activo'
      and public.app_kombax_social_usuario_controla_social_v235(sp.id)
  );
$$;
revoke all on function public.app_kombax_social_usuario_en_tipos_v237(uuid) from public,anon,authenticated;

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
  return query select 'perfiles_seleccionados'::text,null::uuid,null::uuid,'Perfiles concretos…'::text,'Selecciona una o varias identidades KOMBAX que podrán ver esta publicación.'::text,false;
  return query select 'tipos_perfil'::text,null::uuid,null::uuid,'Tipo de perfil…'::text,'Limita la publicación a clubes, competidores, federaciones u otros tipos de perfil.'::text,false;
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
  elsif v_post.audiencia='perfiles_seleccionados' then v_allowed:=public.app_kombax_social_usuario_en_perfiles_v237(v_post.id);
  elsif v_post.audiencia='tipos_perfil' then v_allowed:=public.app_kombax_social_usuario_en_tipos_v237(v_post.id);
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
    when 'kombax_excepto' then 'Todo KOMBAX · con exclusiones' when 'perfiles_seleccionados' then 'Perfiles concretos'
    when 'tipos_perfil' then 'Tipos de perfil' else 'Restringida' end
  from public.kombax_social_publicaciones p where p.id=p_publicacion_id;
$$;
revoke all on function public.app_kombax_social_audiencia_label_v083(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_social_visibility_config_v237(p_post_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_post public.kombax_social_publicaciones;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  select * into v_post from public.kombax_social_publicaciones where id=p_post_id;
  if v_post.id is null then raise exception 'KOMBAX_POST_NOT_FOUND';end if;
  if not public.app_kombax_social_puede_actuar_v051(v_post.autor_perfil_id) then raise exception 'KOMBAX_POST_NOT_ALLOWED';end if;
  return jsonb_build_object(
    'publicacion_id',v_post.id,'autor_perfil_id',v_post.autor_perfil_id,'audiencia',v_post.audiencia,
    'audiencia_club_id',v_post.audiencia_club_id,'audiencia_federacion_social_id',v_post.audiencia_federacion_social_id,
    'club_ids',coalesce((select jsonb_agg(r.club_id order by r.club_id) from public.kombax_social_post_visibility_clubs_v235 r where r.post_id=v_post.id and r.rule='include'),'[]'::jsonb),
    'excluded_club_ids',coalesce((select jsonb_agg(r.club_id order by r.club_id) from public.kombax_social_post_visibility_clubs_v235 r where r.post_id=v_post.id and r.rule='exclude'),'[]'::jsonb),
    'club_selections',coalesce((select jsonb_agg(jsonb_build_object('id',r.club_id,'name',c.nombre,'rule',r.rule) order by c.nombre) from public.kombax_social_post_visibility_clubs_v235 r join public.clubes c on c.id=r.club_id where r.post_id=v_post.id),'[]'::jsonb),
    'profile_ids',coalesce((select jsonb_agg(r.social_id order by r.social_id) from public.kombax_social_post_visibility_profiles_v237 r where r.post_id=v_post.id),'[]'::jsonb),
    'profile_selections',coalesce((select jsonb_agg(jsonb_build_object('id',r.social_id,'name',sp.nombre_publico,'type',public.app_kombax_social_tipo_v051(sp.id)) order by sp.nombre_publico) from public.kombax_social_post_visibility_profiles_v237 r join public.kombax_social_perfiles sp on sp.id=r.social_id where r.post_id=v_post.id),'[]'::jsonb),
    'profile_types',coalesce((select jsonb_agg(r.profile_type order by r.profile_type) from public.kombax_social_post_visibility_types_v237 r where r.post_id=v_post.id),'[]'::jsonb),
    'media_bucket',case when v_post.social_media_id is not null then coalesce((select m.storage_bucket from public.kombax_social_media m where m.id=v_post.social_media_id),'kombax-public-media') when v_post.media_id is not null then 'kombax-public-media' else null end
  );
end $$;
revoke all on function public.app_kombax_social_visibility_config_v237(uuid) from public,anon;
grant execute on function public.app_kombax_social_visibility_config_v237(uuid) to authenticated;


notify pgrst,'reload schema';
commit;
