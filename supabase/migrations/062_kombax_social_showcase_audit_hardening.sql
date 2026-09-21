-- KOMBAX RC13 build 20035 · Social + Showcase audit hardening
begin;

-- Showcase upload path emitted by the client is:
-- <auth.uid()>/showcase/<showcase-space-id>/<filename>
-- storage.foldername() therefore contains exactly those 3 folder segments.
drop policy if exists kombax_showcase_media_insert_v054 on storage.objects;
create policy kombax_showcase_media_insert_v054 on storage.objects
for insert to authenticated
with check (
  bucket_id='kombax-public-media'
  and array_length(storage.foldername(name),1)>=3
  and (storage.foldername(name))[1]=auth.uid()::text
  and (storage.foldername(name))[2]='showcase'
  and public.app_kombax_showcase_puede_gestionar_v045(((storage.foldername(name))[3])::uuid)
);

drop policy if exists kombax_showcase_media_delete_v054 on storage.objects;
create policy kombax_showcase_media_delete_v054 on storage.objects
for delete to authenticated
using (
  bucket_id='kombax-public-media'
  and array_length(storage.foldername(name),1)>=3
  and (storage.foldername(name))[1]=auth.uid()::text
  and (storage.foldername(name))[2]='showcase'
  and public.app_kombax_showcase_puede_gestionar_v045(((storage.foldername(name))[3])::uuid)
);

-- A reply must belong to the same publication and only one reply layer is allowed.
create or replace function public.app_kombax_social_comment_parent_guard_v062()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_parent public.kombax_social_comentarios;
begin
  if new.parent_id is null then return new; end if;
  if new.id is not null and new.parent_id=new.id then raise exception 'KOMBAX_COMMENT_PARENT_SELF'; end if;
  select * into v_parent from public.kombax_social_comentarios c where c.id=new.parent_id;
  if v_parent.id is null or v_parent.estado<>'active' then raise exception 'KOMBAX_COMMENT_PARENT_NOT_AVAILABLE'; end if;
  if v_parent.publicacion_id<>new.publicacion_id then raise exception 'KOMBAX_COMMENT_PARENT_POST_MISMATCH'; end if;
  if v_parent.parent_id is not null then raise exception 'KOMBAX_COMMENT_REPLY_DEPTH_LIMIT'; end if;
  return new;
end $$;
revoke all on function public.app_kombax_social_comment_parent_guard_v062() from public,anon,authenticated;

drop trigger if exists kombax_social_comment_parent_guard_v062 on public.kombax_social_comentarios;
create trigger kombax_social_comment_parent_guard_v062
before insert or update of parent_id,publicacion_id on public.kombax_social_comentarios
for each row execute function public.app_kombax_social_comment_parent_guard_v062();

notify pgrst,'reload schema';
commit;
