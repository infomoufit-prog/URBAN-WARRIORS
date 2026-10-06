-- Administrative presentation is private and independent of the public Social identity.
create table public.kombax_profile_workspace_fix14 (
 profile_id uuid primary key references public.perfiles_kombax_directos(id) on delete cascade,
 avatar_path text, banner_path text, archived boolean not null default false,
 updated_at timestamptz not null default now(), updated_by uuid references public.perfiles(id)
);
alter table public.kombax_profile_workspace_fix14 enable row level security;
revoke all on public.kombax_profile_workspace_fix14 from anon, authenticated;
grant select on public.kombax_profile_workspace_fix14 to authenticated;
create policy workspace_read_fix14 on public.kombax_profile_workspace_fix14 for select to authenticated
 using (public.app_kombax_puede_gestionar_perfil_v070(profile_id,'read'));

create or replace function public.app_kombax_workspace_settings_fix14(p_profile_id uuid default null)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('profile_id',d.id,'avatar_path',w.avatar_path,
 'banner_path',w.banner_path,'archived',coalesce(w.archived,false),
 'can_edit',public.app_kombax_puede_gestionar_perfil_v070(d.id,'edit'),
 'can_archive',d.perfil_id=auth.uid(),'can_delete',d.perfil_id=auth.uid(),
 'can_start_seller',public.app_kombax_puede_gestionar_perfil_v070(d.id,'admin'))),'[]'::jsonb)
 from public.perfiles_kombax_directos d left join public.kombax_profile_workspace_fix14 w on w.profile_id=d.id
 where auth.uid() is not null and (p_profile_id is null or d.id=p_profile_id)
 and public.app_kombax_puede_gestionar_perfil_v070(d.id,'read');
$$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('kombax-workspace-media','kombax-workspace-media',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;

create or replace function public.app_kombax_workspace_media_access_fix14(p_path text,p_write boolean default false)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.perfiles_kombax_directos d
 where d.id::text=split_part(p_path,'/',2)
 and public.app_kombax_puede_gestionar_perfil_v070(d.id,case when p_write then 'edit' else 'read' end)
 and (not p_write or split_part(p_path,'/',1)=auth.uid()::text));
$$;
create policy workspace_media_read_fix14 on storage.objects for select to authenticated
 using(bucket_id='kombax-workspace-media' and public.app_kombax_workspace_media_access_fix14(name,false));
create policy workspace_media_insert_fix14 on storage.objects for insert to authenticated
 with check(bucket_id='kombax-workspace-media' and public.app_kombax_workspace_media_access_fix14(name,true));
create policy workspace_media_delete_fix14 on storage.objects for delete to authenticated
 using(bucket_id='kombax-workspace-media' and public.app_kombax_workspace_media_access_fix14(name,true));

create or replace function public.app_kombax_workspace_save_fix14(p_profile_id uuid,p_action text,p_value text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.kombax_profile_workspace_fix14;v_owner uuid;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 select perfil_id into v_owner from public.perfiles_kombax_directos where id=p_profile_id;
 if v_owner is null then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;
 if p_action='archive' then
  if v_owner<>auth.uid() then raise exception 'KOMBAX_PROFILE_OWNER_REQUIRED';end if;
  if p_value not in ('true','false') or p_value is null then raise exception 'WORKSPACE_VALUE_INVALID';end if;
 elsif p_action in ('avatar','banner') then
  if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'edit') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED';end if;
  if nullif(p_value,'') is not null and (split_part(p_value,'/',2)<>p_profile_id::text
   or not public.app_kombax_workspace_media_access_fix14(p_value,true)
   or not exists(select 1 from storage.objects where bucket_id='kombax-workspace-media' and name=p_value)) then
    raise exception 'WORKSPACE_MEDIA_INVALID';end if;
 else raise exception 'WORKSPACE_ACTION_INVALID';end if;
 insert into public.kombax_profile_workspace_fix14(profile_id) values(p_profile_id) on conflict do nothing;
 select * into v from public.kombax_profile_workspace_fix14 where profile_id=p_profile_id for update;
 update public.kombax_profile_workspace_fix14 set
  archived=case when p_action='archive' then p_value::boolean else archived end,
  avatar_path=case when p_action='avatar' then nullif(p_value,'') else avatar_path end,
  banner_path=case when p_action='banner' then nullif(p_value,'') else banner_path end,
  updated_by=auth.uid(),updated_at=now() where profile_id=p_profile_id;
 return jsonb_build_object('ok',true,'old_path',case when p_action='avatar' then v.avatar_path when p_action='banner' then v.banner_path else null end);
end;
$$;

-- Prepare seller onboarding without publishing a shop, granting Commerce or approving identity.
create or replace function public.app_kombax_seller_entry_fix14(p_profile_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d public.perfiles_kombax_directos;m public.kombax_showcase_marcas;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 select * into d from public.perfiles_kombax_directos where id=p_profile_id for update;
 if d.id is null or d.tipo not in ('marca','federacion','media','competidor','profesional') then raise exception 'SHOWCASE_SELLER_TYPE_NOT_SUPPORTED';end if;
 if not public.app_kombax_puede_gestionar_perfil_v070(d.id,'admin') then raise exception 'SHOWCASE_PROFILE_MANAGEMENT_REQUIRED';end if;
 if d.workflow_estado='suspended' or d.moderacion_estado='suspendido' then raise exception 'KOMBAX_PROFILE_SUSPENDED';end if;
 select * into m from public.kombax_showcase_marcas where perfil_directo_id=d.id for update;
 if m.id is null then
  insert into public.kombax_showcase_marcas(sujeto_tipo,perfil_directo_id,slug,nombre,descripcion,web_url,verificada,estado,creada_por)
  values(d.tipo,d.id,'workspace-'||replace(d.id::text,'-',''),d.nombre_publico,d.descripcion,d.web_publica,false,'borrador',auth.uid()) returning * into m;
 end if;
 -- The owner's existing rights remain anchored to the entity; no delegated permanent grant.
 insert into public.kombax_showcase_gestores(marca_id,perfil_id,rol,asignado_por)
 values(m.id,d.perfil_id,'responsable',auth.uid()) on conflict do nothing;
 return to_jsonb(m);
end;
$$;

revoke all on function public.app_kombax_workspace_settings_fix14(uuid),public.app_kombax_workspace_save_fix14(uuid,text,text),
 public.app_kombax_workspace_media_access_fix14(text,boolean),public.app_kombax_seller_entry_fix14(uuid) from public,anon;
grant execute on function public.app_kombax_workspace_settings_fix14(uuid),public.app_kombax_workspace_save_fix14(uuid,text,text),
 public.app_kombax_workspace_media_access_fix14(text,boolean),public.app_kombax_seller_entry_fix14(uuid) to authenticated;
-- Delegated administrators can complete onboarding while their role remains active.
create or replace function kombax_payments.can_manage_provider(p_actor uuid,p_provider uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.kombax_showcase_gestores g where g.marca_id=p_provider and g.perfil_id=p_actor and g.activo)
 or exists(select 1 from public.kombax_showcase_marcas m join public.miembros_club mc on mc.club_id=m.club_id
  where m.id=p_provider and mc.perfil_id=p_actor and mc.activo and mc.rol in('direccion','secretaria','economia'))
 or exists(select 1 from public.kombax_platform_admins pa where pa.perfil_id=p_actor and pa.activo)
 or (p_actor=auth.uid() and exists(select 1 from public.kombax_showcase_marcas m
  where m.id=p_provider and m.perfil_directo_id is not null
  and public.app_kombax_puede_gestionar_perfil_v070(m.perfil_directo_id,'admin')));
$$;
notify pgrst,'reload schema';
