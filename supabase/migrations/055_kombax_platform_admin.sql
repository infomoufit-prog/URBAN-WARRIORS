-- KOMBAX build 20028 · 055 · Administración global de plataforma.
-- No existe bootstrap por email: el primer administrador se concede por UUID desde SQL controlado.
begin;

create table if not exists public.kombax_platform_admins(
  perfil_id uuid primary key references public.perfiles(id) on delete cascade,
  nivel text not null default 'admin' check(nivel in ('admin','owner')),
  activo boolean not null default true,
  asignado_por uuid references public.perfiles(id) on delete set null,
  motivo text check(char_length(coalesce(motivo,''))<=500),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);
alter table public.kombax_platform_admins enable row level security;
revoke all on public.kombax_platform_admins from public,anon,authenticated;

create or replace function public.app_kombax_es_platform_admin_v055()
returns boolean language sql stable security definer set search_path=public,auth as $$
  select auth.uid() is not null and exists(select 1 from public.kombax_platform_admins a where a.perfil_id=auth.uid() and a.activo);
$$;
revoke all on function public.app_kombax_es_platform_admin_v055() from public,anon;
grant execute on function public.app_kombax_es_platform_admin_v055() to authenticated;

-- Un administrador global también puede ejercer moderación/verificación sin necesitar un segundo rol manual.
create or replace function public.app_kombax_es_moderador_v041()
returns boolean language sql stable security definer set search_path=public,auth as $$
  select auth.uid() is not null and (
    exists(select 1 from public.kombax_moderadores_globales m where m.perfil_id=auth.uid() and m.activo)
    or public.app_kombax_es_platform_admin_v055()
  );
$$;
revoke all on function public.app_kombax_es_moderador_v041() from public,anon;
grant execute on function public.app_kombax_es_moderador_v041() to authenticated;

create or replace function public.app_kombax_platform_context_v055()
returns jsonb language sql stable security definer set search_path=public,auth as $$
  select case when public.app_kombax_es_platform_admin_v055() then
    jsonb_build_object('authorized',true,'nivel',(select nivel from public.kombax_platform_admins where perfil_id=auth.uid() and activo limit 1))
  else jsonb_build_object('authorized',false) end;
$$;
revoke all on function public.app_kombax_platform_context_v055() from public,anon;
grant execute on function public.app_kombax_platform_context_v055() to authenticated;

create or replace function public.app_kombax_platform_dashboard_v055()
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  select jsonb_build_object(
    'clubs',coalesce((select jsonb_agg(x) from (
      select jsonb_build_object(
        'id',c.id,'nombre',c.nombre,'slug',c.slug,'activo',c.activo,
        'miembros',(select count(*) from public.miembros_club m where m.club_id=c.id and m.activo),
        'social_profile_id',(select sp.id from public.kombax_social_perfiles sp where sp.sujeto_tipo='club' and sp.club_id=c.id limit 1),
        'showcase_provider_id',(select sh.id from public.kombax_showcase_marcas sh where sh.sujeto_tipo='club' and sh.club_id=c.id limit 1)
      ) x from public.clubes c order by c.nombre
    ) q),'[]'::jsonb),
    'counts',jsonb_build_object(
      'clubs',(select count(*) from public.clubes where activo),
      'accounts',(select count(*) from public.perfiles),
      'memberships',(select count(*) from public.miembros_club where activo),
      'profiles',(select count(*) from public.kombax_social_perfiles where estado='activo'),
      'pending_verifications',(select count(*) from public.kombax_solicitudes_alta where estado in ('submitted','under_review','needs_information')),
      'open_reports',(select count(*) from public.kombax_social_reportes where estado in ('pendiente','en_revision')),
      'showcase_items',(select count(*) from public.kombax_showcase_elementos where estado='publicado'),
      'relations',(select count(*) from public.kombax_relaciones where estado='confirmed'),
      'pending_relations',(select count(*) from public.kombax_relaciones where estado='pending'),
      'pending_contacts',(select count(*) from public.kombax_social_contactos where estado='pendiente')
    ),
    'pending_verifications',coalesce((select jsonb_agg(x) from (
      select jsonb_build_object('id',a.id,'tipo',a.tipo,'nombre_publico',a.nombre_publico,'estado',a.estado,'creado_en',a.creado_en,'actualizado_en',a.actualizado_en) x
      from public.kombax_solicitudes_alta a where a.estado in ('submitted','under_review','needs_information') order by a.actualizado_en desc limit 30
    ) q),'[]'::jsonb),
    'open_reports',coalesce((select jsonb_agg(x) from (
      select jsonb_build_object('id',r.id,'objetivo_tipo',r.objetivo_tipo,'motivo',r.motivo,'detalle',r.detalle,'estado',r.estado,'creado_en',r.creado_en) x
      from public.kombax_social_reportes r where r.estado in ('pendiente','en_revision') order by r.creado_en limit 30
    ) q),'[]'::jsonb),
    'recent_profiles',coalesce((select jsonb_agg(x) from (
      select jsonb_build_object(
        'id',sp.id,'nombre_publico',sp.nombre_publico,'tipo',public.app_kombax_social_tipo_v051(sp.id),
        'estado',sp.estado,'verificado',sp.verificado,'club_id',sp.club_id,'club_nombre',c.nombre,'actualizado_en',sp.actualizado_en
      ) x
      from public.kombax_social_perfiles sp left join public.clubes c on c.id=sp.club_id
      where sp.estado<>'cerrado' order by sp.actualizado_en desc limit 40
    ) q),'[]'::jsonb),
    'recent_audit',coalesce((select jsonb_agg(x) from (
      select jsonb_build_object(
        'accion',a.accion,'club_id',a.club_id,'actor_perfil_id',a.actor_perfil_id,
        'actor_nombre',nullif(btrim(concat_ws(' ',p.nombre,p.apellidos)),''),
        'objeto_tipo',a.objeto_tipo,'objeto_id',a.objeto_id,'creado_en',a.creado_en
      ) x
      from public.kombax_actor_audit a left join public.perfiles p on p.id=a.actor_perfil_id
      order by a.creado_en desc limit 40
    ) q),'[]'::jsonb)
  ) into v;
  return v;
end $$;
revoke all on function public.app_kombax_platform_dashboard_v055() from public,anon;
grant execute on function public.app_kombax_platform_dashboard_v055() to authenticated;

create or replace function public.app_kombax_platform_profiles_v055(p_query text default '',p_limit integer default 100)
returns table(id uuid,nombre_publico text,tipo text,estado text,verificado boolean,club_id uuid,club_nombre text,actualizado_en timestamptz)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_query text:=lower(btrim(coalesce(p_query,'')));
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  return query
  select sp.id,sp.nombre_publico,public.app_kombax_social_tipo_v051(sp.id),sp.estado,sp.verificado,sp.club_id,c.nombre,sp.actualizado_en
  from public.kombax_social_perfiles sp left join public.clubes c on c.id=sp.club_id
  where v_query='' or lower(coalesce(sp.nombre_publico,'')||' '||coalesce(c.nombre,'')||' '||coalesce(sp.slug,'')) like '%'||v_query||'%'
  order by sp.actualizado_en desc
  limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_platform_profiles_v055(text,integer) from public,anon;
grant execute on function public.app_kombax_platform_profiles_v055(text,integer) to authenticated;

create or replace function public.app_kombax_platform_club_v055(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  select jsonb_build_object(
    'club',to_jsonb(c)-'cif'-'telefono'-'email'-'direccion',
    'public_profile',coalesce((select to_jsonb(pc) from public.perfiles_club_publicos pc where pc.club_id=c.id),'{}'::jsonb),
    'team',coalesce((select jsonb_agg(jsonb_build_object(
      'perfil_id',m.perfil_id,
      'nombre',coalesce(nullif(btrim(concat_ws(' ',p.nombre,p.apellidos)),''),m.perfil_id::text),
      'rol',m.rol,'coordinacion',coalesce(m.coordinacion,false),'activo',m.activo,
      'permisos',coalesce((select jsonb_agg(jsonb_build_object('permiso',tp.permiso,'activo',tp.activo) order by tp.permiso) from public.kombax_club_team_permissions tp where tp.club_id=m.club_id and tp.perfil_id=m.perfil_id),'[]'::jsonb)
    ) order by coalesce(p.nombre,''),coalesce(p.apellidos,''),m.rol)
    from public.miembros_club m left join public.perfiles p on p.id=m.perfil_id where m.club_id=c.id and m.activo),'[]'::jsonb),
    'social_profile_id',(select sp.id from public.kombax_social_perfiles sp where sp.sujeto_tipo='club' and sp.club_id=c.id limit 1),
    'showcase_provider_id',(select s.id from public.kombax_showcase_marcas s where s.sujeto_tipo='club' and s.club_id=c.id limit 1)
  ) into v from public.clubes c where c.id=p_club_id;
  if v is null then raise exception 'CLUB_NOT_FOUND';end if;
  return v;
end $$;
revoke all on function public.app_kombax_platform_club_v055(uuid) from public,anon;
grant execute on function public.app_kombax_platform_club_v055(uuid) to authenticated;

create or replace function public.app_kombax_platform_mutate_v055(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_club uuid;v_profile uuid;v_perm text;v_active boolean;v_role text;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);
  end if;

  if p_operation='kombax.platform.team.permission.set' then
    begin v_club:=(v_payload->>'club_id')::uuid;v_profile:=(v_payload->>'perfil_id')::uuid;exception when others then raise exception 'PLATFORM_PERMISSION_TARGET_INVALID';end;
    v_perm:=v_payload->>'permiso';v_active:=coalesce((v_payload->>'activo')::boolean,true);
    if v_perm not in ('social.act_as_club','profile.public.manage','showcase.manage','relations.manage','contacts.manage') then raise exception 'PLATFORM_PERMISSION_INVALID';end if;
    if not exists(select 1 from public.miembros_club where club_id=v_club and perfil_id=v_profile and activo) then raise exception 'PLATFORM_PERMISSION_MEMBERSHIP_REQUIRED';end if;
    insert into public.kombax_club_team_permissions(club_id,perfil_id,permiso,activo,concedido_por) values(v_club,v_profile,v_perm,v_active,v_uid)
      on conflict(club_id,perfil_id,permiso) do update set activo=excluded.activo,concedido_por=excluded.concedido_por,actualizado_en=now();
    v_result:=jsonb_build_object('club_id',v_club,'perfil_id',v_profile,'permiso',v_perm,'activo',v_active);
  elsif p_operation='kombax.platform.moderator.set' then
    begin v_profile:=(v_payload->>'perfil_id')::uuid;exception when others then raise exception 'PLATFORM_MODERATOR_TARGET_INVALID';end;
    v_role:=lower(coalesce(nullif(v_payload->>'rol',''),'moderador'));if v_role not in ('moderador','administrador') then raise exception 'PLATFORM_MODERATOR_ROLE_INVALID';end if;
    v_active:=coalesce((v_payload->>'activo')::boolean,true);
    insert into public.kombax_moderadores_globales(perfil_id,rol,activo,asignado_por) values(v_profile,v_role,v_active,v_uid)
      on conflict(perfil_id) do update set rol=excluded.rol,activo=excluded.activo,asignado_por=excluded.asignado_por;
    v_result:=jsonb_build_object('perfil_id',v_profile,'rol',v_role,'activo',v_active);
  else raise exception 'PLATFORM_OPERATION_NOT_ALLOWED';end if;

  insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle)
  values(v_uid,v_club,p_operation,'platform_admin',coalesce(v_profile,v_club),coalesce(v_result,'{}'::jsonb));
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',v_result);
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_platform_mutate_v055(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_platform_mutate_v055(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
