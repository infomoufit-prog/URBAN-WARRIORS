begin;
create or replace function kombax_moderation.notify(p_channel text,p_id uuid,p_action text,p_reason text,p_author uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_event uuid:=gen_random_uuid();
begin
 insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,subject_type,subject_id)
 select null,r.uid,'moderation:'||v_event::text,'owner_action',
 'RevisiÃ³n de contenido: '||p_action,left(p_reason,1000),case when r.uid=p_author then 'notifications' else 'platform-admin' end,
 jsonb_build_object('priority','warning','requiere_accion',p_action in ('Retirada automática','Revisión solicitada'),'owner_section','owner-moderation','channel',p_channel,'action',p_action,'content_id',p_id,'review_available',true),
 'moderation',p_id
 from (select p_author uid where p_author is not null union select a.perfil_id from public.kombax_platform_admins a where a.activo
  union select m.perfil_id from public.miembros_club m where m.activo and m.rol in ('direccion','comunicacion') and m.club_id=case when p_channel='social' then (select s.club_id from public.kombax_social_publicaciones p join public.kombax_social_perfiles s on s.id=p.autor_perfil_id where p.id=p_id) else (select b.club_id from public.kombax_showcase_elementos e join public.kombax_showcase_marcas b on b.id=e.marca_id where e.id=p_id) end) r
 on conflict do nothing;
end $$;
commit;
