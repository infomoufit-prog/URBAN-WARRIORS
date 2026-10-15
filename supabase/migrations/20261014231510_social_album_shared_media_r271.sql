begin;
-- Removing an album entry must not invalidate posts that still use its file.
create or replace function private.kombax_social_album_remove_r271(p_media_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.kombax_social_media; linked boolean; shared boolean;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into m from public.kombax_social_media where id=p_media_id for update;
 if m.id is null or not public.app_kombax_social_puede_gestionar_perfil_publico_r117(m.social_profile_id) then
   raise exception 'KOMBAX_SOCIAL_MEDIA_NOT_OWNED';
 end if;
 linked:=exists(select 1 from public.kombax_social_publicaciones p where p.social_media_id=m.id);
 -- Keep the original and cover for posts and for other active album references.
 shared:=linked or exists(select 1 from public.kombax_social_media s where s.id<>m.id and s.storage_path=m.storage_path and s.estado in ('active','pending_review'))
   or exists(select 1 from public.kombax_club_media c where c.storage_path=m.storage_path and c.estado='active')
   or exists(select 1 from public.kombax_perfil_media d where d.storage_path=m.storage_path and d.estado='active');
 update public.kombax_social_media set en_album=false,
   estado=case when linked then estado else 'removed' end,actualizado_en=now() where id=m.id;
 update public.kombax_social_perfiles set
   avatar_path=case when avatar_path=m.storage_path then null else avatar_path end,
   banner_path=case when banner_path=m.storage_path then null else banner_path end,
   actualizado_en=now() where id=m.social_profile_id;
 return jsonb_build_object('id',m.id,'storage_path',case when shared then null else m.storage_path end,
   'estado',case when linked then m.estado else 'removed' end,'en_album',false,
   'media_retained',linked,'cleanup_allowed',not shared);
end $$;
revoke all on function private.kombax_social_album_remove_r271(uuid) from public,anon,authenticated;
-- Preserve the existing endpoint, authorization/idempotency envelope and all other operations.
do $$
declare original text; revised text;
begin
 select pg_get_functiondef('public.app_kombax_social_mutate_v053(text,jsonb,uuid)'::regprocedure) into original;
 if position('private.kombax_social_album_remove_r271' in original)>0 then return;end if;
 revised:=regexp_replace(original,
   'elsif p_operation=''kombax.social.media.remove'' then[\s\S]*?elsif p_operation=''kombax.social.publicar'' then',
   'elsif p_operation=''kombax.social.media.remove'' then
    begin v_media_id:=(v_payload->>''media_id'')::uuid;exception when others then raise exception ''KOMBAX_SOCIAL_MEDIA_ID_INVALID'';end;
    v_result:=private.kombax_social_album_remove_r271(v_media_id);
  elsif p_operation=''kombax.social.publicar'' then');
 if revised=original then raise exception 'R271_ALBUM_ENDPOINT_SIGNATURE_CHANGED';end if;
 execute revised;
end $$;
notify pgrst,'reload schema';
commit;
