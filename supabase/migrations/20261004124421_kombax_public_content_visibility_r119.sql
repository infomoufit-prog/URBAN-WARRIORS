begin;
-- Public lists must never include an intervention locked by moderation.
do $$ declare f record; patched text; begin
 for f in select p.oid,p.proname,pg_get_functiondef(p.oid) definition from pg_catalog.pg_proc p
 join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
 and (p.proname in ('app_kombax_social_feed_v238','app_kombax_social_feed_v239','app_kombax_social_feed_v237','app_kombax_social_feed_v236','app_kombax_social_feed_v085','app_kombax_social_profile_posts_v256','app_kombax_social_profile_posts_v255','app_kombax_social_profile_posts_v099'))
 loop
  patched:=replace(f.definition,'p.estado=''activa''','p.estado=''activa'' and not exists(select 1 from kombax_moderation.content_state cms where cms.channel=''social'' and cms.content_id=p.id and cms.state in (''hidden'',''deleted''))');
  if patched=f.definition then raise exception 'Visibility predicate missing in %',f.proname;end if;
  execute patched;
 end loop;
 for f in select pg_get_functiondef(p.oid) definition from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('app_kombax_showcase_list_v054','app_kombax_showcase_list_v042')
 loop
  patched:=replace(f.definition,'e.estado=''publicado''','e.estado=''publicado'' and not exists(select 1 from kombax_moderation.content_state cms where cms.channel=''showcase'' and cms.content_id=e.id and cms.state in (''hidden'',''deleted''))');
  if patched=f.definition then raise exception 'Showcase visibility predicate missing';end if;execute patched;
 end loop;
 select pg_get_functiondef(p.oid) into patched from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='app_kombax_content_action_r118';
 patched:=replace(patched,'if p_action is distinct from ''delete'' then','p_confirmation:=upper(btrim(coalesce(p_confirmation,'''')));'||chr(10)||' if p_action is distinct from ''delete'' then');
 execute patched;
end $$;

-- Revalidate cards already displayed, without exposing content or private document fields.
create function public.app_kombax_content_visible_r119(p_channel text,p_ids uuid[]) returns uuid[]
language plpgsql stable security definer set search_path='' as $$
declare result uuid[];
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 if coalesce(cardinality(p_ids),0)>40 then raise exception 'CONTENT_IDS_LIMIT';end if;
 if p_channel='social' then
  select array_agg(p.id) into result from public.kombax_social_publicaciones p
  join public.kombax_social_perfiles s on s.id=p.autor_perfil_id
  where p.id=any(p_ids) and p.estado='activa' and s.visible and s.estado='activo'
   and public.app_kombax_social_puede_ver_publicacion_v083(p.id)
   and not exists(select 1 from kombax_moderation.content_state cms where cms.channel='social' and cms.content_id=p.id and cms.state in ('hidden','deleted'));
 elsif p_channel='showcase' then
  select array_agg(p.id) into result from public.kombax_showcase_elementos p
  join public.kombax_showcase_marcas m on m.id=p.marca_id
  where p.id=any(p_ids) and p.estado='publicado' and m.estado='publicada'
   and not exists(select 1 from kombax_moderation.content_state cms where cms.channel='showcase' and cms.content_id=p.id and cms.state in ('hidden','deleted'));
 else raise exception 'INVALID_CHANNEL';end if;
 return coalesce(result,'{}'::uuid[]);
end $$;
revoke all on function public.app_kombax_content_visible_r119(text,uuid[]) from public,anon;
grant execute on function public.app_kombax_content_visible_r119(text,uuid[]) to authenticated;
commit;
