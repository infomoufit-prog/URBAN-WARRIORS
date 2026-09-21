-- KOMBAX RC13 build 20.094 · 166 · History + final Events hardening
begin;

create or replace function public.app_kombax_evento_publico_slug_v166(p_slug text)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_id uuid;v_base jsonb;v_eng jsonb;v_fights jsonb;v_media jsonb;v_phase text;
begin
 select e.id into v_id from public.kombax_eventos_publicos e where e.slug=lower(btrim(coalesce(p_slug,''))) and e.visibilidad='publico'
   and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') limit 1;
 if v_id is null then return null; end if;
 v_base:=public.app_kombax_evento_publico_detalle_v161(v_id);if v_base is null then return null;end if;
 select to_jsonb(x) into v_eng from public.app_kombax_evento_engagement_v162(v_id) x;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_fights from public.app_kombax_evento_resultados_v164(v_id) x;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_media from public.app_kombax_evento_media_v165(v_id) x;
 v_phase:=public.app_kombax_evento_estado_temporal_v164(v_id);
 return v_base || jsonb_build_object('engagement',coalesce(v_eng,jsonb_build_object('interesados',0,'asistiran',0,'mi_estado',null,'mis_notificaciones',false)),'fights',coalesce(v_fights,'[]'::jsonb),'media',coalesce(v_media,'[]'::jsonb),'fase_temporal',v_phase);
end $$;
revoke all on function public.app_kombax_evento_publico_slug_v166(text) from public;
grant execute on function public.app_kombax_evento_publico_slug_v166(text) to anon,authenticated;

create or replace function public.app_kombax_evento_historial_competidor_v166(p_social_profile_id uuid,p_limit integer default 60)
returns table(
 evento_id uuid,evento_slug text,evento_nombre text,fecha_inicio timestamptz,combate_id uuid,rival_nombre text,
 resultado_estado text,resultado text,metodo_resultado text,ganador boolean,asalto smallint,tiempo_resultado text
) language sql stable security definer set search_path=public as $$
 select e.id,e.slug,e.nombre,e.fecha_inicio,f.id,
   case when a.competidor_social_profile_id=p_social_profile_id then b.nombre_publico else a.nombre_publico end,
   f.resultado_estado,f.resultado,f.metodo_resultado,
   case when f.resultado_estado='oficial' then f.ganador_participante_id=(case when a.competidor_social_profile_id=p_social_profile_id then a.id else b.id end) else null end,
   f.asalto,f.tiempo_resultado
 from public.kombax_evento_combates_publicos f
 join public.kombax_eventos_publicos e on e.id=f.evento_id and e.visibilidad='publico' and e.estado='finalizado'
 join public.kombax_evento_participantes_publicos a on a.id=f.participante_a_id
 join public.kombax_evento_participantes_publicos b on b.id=f.participante_b_id
 where f.visible_publico and f.resultado_estado in ('oficial','anulado')
   and p_social_profile_id is not null
   and p_social_profile_id in (a.competidor_social_profile_id,b.competidor_social_profile_id)
 order by e.fecha_inicio desc nulls last,f.orden nulls last,f.id
 limit least(100,greatest(1,coalesce(p_limit,60)));
$$;
revoke all on function public.app_kombax_evento_historial_competidor_v166(uuid,integer) from public;
grant execute on function public.app_kombax_evento_historial_competidor_v166(uuid,integer) to anon,authenticated;

create or replace function public.app_kombax_eventos_mutate_v166(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
begin
 return public.app_kombax_eventos_mutate_v165(p_operation,coalesce(p_payload,'{}'::jsonb),p_request_id);
end $$;
revoke all on function public.app_kombax_eventos_mutate_v166(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v166(text,jsonb,uuid) to authenticated;

-- Final ACL: direct Events tables remain RPC-only.
revoke all on public.kombax_eventos_publicos,public.kombax_evento_entidades,public.kombax_evento_participantes_publicos,public.kombax_evento_combates_publicos,public.kombax_evento_interes,public.kombax_evento_social_links,public.kombax_evento_media from public,anon,authenticated;

comment on table public.kombax_evento_media is 'Media pública editorial de KOMBAX Eventos. Storage privado; exposición mediante RPC + URL firmada controlada.';
comment on function public.app_kombax_evento_publico_slug_v166(text) is 'Detalle público 20.094 con estado temporal, resultados y media visible. No consulta Mi Club > Eventos.';
notify pgrst,'reload schema';
commit;
