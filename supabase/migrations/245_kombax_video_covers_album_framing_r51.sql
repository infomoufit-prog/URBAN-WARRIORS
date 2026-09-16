-- KOMBAX 20.101 R51 · Portadas de vídeo + encuadre equilibrado de álbum.
-- Conserva el archivo original. La portada es un asset separado y media_presentation
-- almacena únicamente metadatos de presentación/encuadre.
begin;

create or replace function public.app_kombax_media_presentation_normalize_v187(p_value jsonb)
returns jsonb
language plpgsql immutable
set search_path=public
as $$
declare
  v jsonb:=case when jsonb_typeof(coalesce(p_value,'{}'::jsonb))='object' then coalesce(p_value,'{}'::jsonb) else '{}'::jsonb end;
  v_fit text:=lower(coalesce(v->>'fit','auto'));
  v_orientation text:=lower(coalesce(v->>'orientation','auto'));
  v_x numeric;v_y numeric;v_zoom numeric;
  v_cover_mode text:=lower(nullif(btrim(coalesce(v->>'cover_mode','')),''));
  v_cover_bucket text:=nullif(btrim(coalesce(v->>'cover_storage_bucket','')),'');
  v_cover_path text:=nullif(btrim(coalesce(v->>'cover_storage_path','')),'');
  v_cover_mime text:=lower(nullif(btrim(coalesce(v->>'cover_mime_type','')),''));
  v_cover_time numeric;
  v_out jsonb;
begin
  if v_fit not in ('auto','cover','contain','balanced') then v_fit:='auto'; end if;
  if v_orientation not in ('auto','portrait','landscape','square') then v_orientation:='auto'; end if;
  begin v_x:=(v->>'focus_x')::numeric; exception when others then v_x:=50; end;
  begin v_y:=(v->>'focus_y')::numeric; exception when others then v_y:=50; end;
  begin v_zoom:=(v->>'zoom')::numeric; exception when others then v_zoom:=1; end;
  begin v_cover_time:=(v->>'cover_time')::numeric; exception when others then v_cover_time:=0; end;
  v_x:=greatest(0,least(100,coalesce(v_x,50)));
  v_y:=greatest(0,least(100,coalesce(v_y,50)));
  v_zoom:=greatest(1,least(2.5,coalesce(v_zoom,1)));
  v_cover_time:=greatest(0,least(60.2,coalesce(v_cover_time,0)));
  v_out:=jsonb_build_object('fit',v_fit,'focus_x',round(v_x,2),'focus_y',round(v_y,2),'zoom',round(v_zoom,2),'orientation',v_orientation);

  -- Solo preserva metadatos de portada si la ruta y el bucket son válidos.
  if v_cover_path is not null
     and length(v_cover_path)<=900
     and v_cover_path !~ '(^/|(^|/)\.\.(/|$))'
     and v_cover_bucket in ('kombax-public-media','kombax-restricted-media','kombax-events-media')
  then
    if v_cover_mode not in ('auto','frame','upload') then v_cover_mode:='auto'; end if;
    if v_cover_mime not in ('image/jpeg','image/png','image/webp') then v_cover_mime:='image/webp'; end if;
    v_out:=v_out||jsonb_build_object(
      'cover_mode',v_cover_mode,
      'cover_storage_bucket',v_cover_bucket,
      'cover_storage_path',v_cover_path,
      'cover_mime_type',v_cover_mime,
      'cover_time',round(v_cover_time,2)
    );
  end if;
  return v_out;
end $$;
revoke all on function public.app_kombax_media_presentation_normalize_v187(jsonb) from public,anon,authenticated;

-- Lector R21 ampliado: los assets públicos mantienen lectura anónima y los media
-- Social restringidos solo entregan metadatos al actor autorizado o a quien pueda
-- ver una publicación activa que use ese media.
create or replace function public.app_kombax_media_presentations_v187(p_scope text,p_ids uuid[])
returns table(id uuid,presentation jsonb)
language plpgsql stable security definer
set search_path=public,auth
as $$
declare v_scope text:=lower(btrim(coalesce(p_scope,'')));begin
  if coalesce(array_length(p_ids,1),0)=0 then return; end if;
  if v_scope='event_participant' then
    return query select p.id,coalesce(p.media_presentation,'{}'::jsonb) from public.kombax_evento_participantes_publicos p where p.id=any(p_ids) and coalesce(p.visible_publico,true)=true and p.estado_inscripcion='aceptada';
  elsif v_scope='event_media' then
    return query select m.id,coalesce(m.media_presentation,'{}'::jsonb) from public.kombax_evento_media m where m.id=any(p_ids) and m.estado='visible';
  elsif v_scope='social_media' then
    return query
      select m.id,coalesce(m.media_presentation,'{}'::jsonb)
      from public.kombax_social_media m
      where m.id=any(p_ids) and m.estado='active'
        and (
          coalesce(m.storage_bucket,'kombax-public-media')='kombax-public-media'
          or (
            auth.uid() is not null and (
              public.app_kombax_social_puede_actuar_v051(m.social_profile_id)
              or exists(
                select 1 from public.kombax_social_publicaciones p
                where p.social_media_id=m.id and p.estado='activa'
                  and public.app_kombax_social_puede_ver_publicacion_v083(p.id)
              )
            )
          )
        );
  elsif v_scope='profile_media' then
    return query select m.id,coalesce(m.media_presentation,'{}'::jsonb) from public.kombax_perfil_media m where m.id=any(p_ids) and m.estado='active';
  elsif v_scope='club_media' then
    return query select m.id,coalesce(m.media_presentation,'{}'::jsonb) from public.kombax_club_media m where m.id=any(p_ids) and m.estado='active';
  elsif v_scope='showcase_item' then
    return query select e.id,coalesce(e.imagen_presentacion,'{}'::jsonb) from public.kombax_showcase_elementos e where e.id=any(p_ids) and e.estado='publicado';
  elsif v_scope='material_item' then
    if auth.uid() is null then return; end if;
    return query select m.id,coalesce(m.media_presentation,'{}'::jsonb) from public.material_catalogo m where m.id=any(p_ids) and public.es_miembro_club(m.club_id);
  else
    return;
  end if;
end $$;
revoke all on function public.app_kombax_media_presentations_v187(text,uuid[]) from public;
grant execute on function public.app_kombax_media_presentations_v187(text,uuid[]) to anon,authenticated;

-- Resolver de assets del álbum de Events para el Edge Function. Permite asset
-- original o cover y conserva la misma regla: evento público o gestor autenticado.
create or replace function public.app_kombax_evento_media_asset_v251(p_media_id uuid,p_variant text default 'asset')
returns table(storage_bucket text,storage_path text,external_url text,mime_type text,tipo text,allow_download boolean)
language plpgsql stable security definer
set search_path=public,auth
as $$
declare
  v_variant text:=lower(btrim(coalesce(p_variant,'asset')));
begin
  if v_variant not in ('asset','cover') then return; end if;
  return query
  select
    case when v_variant='cover' then nullif(m.media_presentation->>'cover_storage_bucket','') else m.storage_bucket end,
    case when v_variant='cover' then nullif(m.media_presentation->>'cover_storage_path','') else m.storage_path end,
    case when v_variant='cover' then null::text else m.external_url end,
    case when v_variant='cover' then coalesce(nullif(m.media_presentation->>'cover_mime_type',''),'image/webp') else m.mime_type end,
    case when v_variant='cover' then 'cover'::text else m.tipo end,
    case when v_variant='cover' then false else m.allow_download end
  from public.kombax_evento_media m
  join public.kombax_eventos_publicos e on e.id=m.evento_id
  where m.id=p_media_id
    and m.estado='visible'
    and (m.expires_at is null or m.expires_at>now())
    and (
      (e.visibilidad='publico' and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado'))
      or (auth.uid() is not null and public.app_kombax_evento_puede_gestionar_v160(e.id))
    )
    and (v_variant<>'cover' or (
      nullif(m.media_presentation->>'cover_storage_path','') is not null
      and m.media_presentation->>'cover_storage_bucket'='kombax-events-media'
    ))
  limit 1;
end $$;
revoke all on function public.app_kombax_evento_media_asset_v251(uuid,text) from public;
grant execute on function public.app_kombax_evento_media_asset_v251(uuid,text) to anon,authenticated,service_role;
comment on function public.app_kombax_evento_media_asset_v251(uuid,text) is 'R51 asset/cover resolver for KOMBAX Events. Public event or authenticated event manager only.';

notify pgrst,'reload schema';
commit;
