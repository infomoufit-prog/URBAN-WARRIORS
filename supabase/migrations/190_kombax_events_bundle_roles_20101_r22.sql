-- KOMBAX 20.101 R22 · bundle fight roles completion
begin;
create or replace function public.app_kombax_evento_bundle_v189(p_evento_id uuid,p_workspace_club_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_base jsonb;v_media jsonb;v_eng jsonb;v_manage boolean:=false;v_fights jsonb;
begin
 v_base:=public.app_kombax_evento_publico_detalle_v178(p_evento_id);
 if v_base is null then return null; end if;
 select coalesce(jsonb_agg(to_jsonb(f) || jsonb_build_object('co_estelar',coalesce(raw.co_estelar,false)) order by raw.destacado desc,raw.co_estelar desc,raw.orden nulls last,raw.hora_programada nulls last,raw.creado_en,raw.id),'[]'::jsonb)
 into v_fights
 from public.app_kombax_evento_combates_v161(p_evento_id) f
 join public.kombax_evento_combates_publicos raw on raw.id=f.id;
 select coalesce(jsonb_agg(to_jsonb(m) || jsonb_build_object('media_presentation',coalesce(em.media_presentation,'{}'::jsonb)) order by m.orden,m.creado_en desc),'[]'::jsonb)
   into v_media
 from public.app_kombax_evento_media_v175(p_evento_id,p_workspace_club_id) m
 left join public.kombax_evento_media em on em.id=m.id;
 select to_jsonb(x) into v_eng from public.app_kombax_evento_engagement_v162(p_evento_id) x limit 1;
 if auth.uid() is not null then
   if p_workspace_club_id is not null then select x.puede_gestionar into v_manage from public.app_kombax_evento_contexto_gestion_v171(p_evento_id,p_workspace_club_id) x;
   else v_manage:=coalesce((v_base->>'can_manage')::boolean,false); end if;
 end if;
 return jsonb_set(v_base,'{fights}',coalesce(v_fights,'[]'::jsonb),true)
   || jsonb_build_object('media',coalesce(v_media,'[]'::jsonb),'engagement',coalesce(v_eng,'null'::jsonb),'can_manage',coalesce(v_manage,false));
end $$;
revoke all on function public.app_kombax_evento_bundle_v189(uuid,uuid) from public;
grant execute on function public.app_kombax_evento_bundle_v189(uuid,uuid) to anon,authenticated;
notify pgrst,'reload schema';
commit;
