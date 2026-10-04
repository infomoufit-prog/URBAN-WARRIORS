begin;
create schema if not exists kombax_documents;
revoke all on schema kombax_documents from public,anon,authenticated;
create function kombax_documents.club_logo(p_id uuid) returns text language sql stable security definer set search_path='' as $$
 select coalesce(nullif(btrim(p.logo_url),''),nullif(btrim(c.logo_url),'')) from public.clubes c left join public.perfiles_club_publicos p on p.club_id=c.id where c.id=p_id;
$$;
create function kombax_documents.event_logo(p_id uuid) returns text language sql stable security definer set search_path='' as $$
 select coalesce(kombax_documents.club_logo(e.creador_club_id),
 (select nullif(btrim(public.app_kombax_social_avatar_url_v063(s.id)),'') from public.kombax_social_perfiles s where s.perfil_directo_id=e.creador_perfil_directo_id order by s.id limit 1),
 (select nullif(btrim(m.logo_url),'') from public.kombax_showcase_marcas m where m.perfil_directo_id=e.creador_perfil_directo_id order by m.actualizado_en desc limit 1))
 from public.kombax_eventos_publicos e where e.id=p_id;
$$;
create or replace function public.app_finance_report_public_logo_r104() returns trigger language plpgsql security definer set search_path='' as $$
begin new.snapshot:=jsonb_set(new.snapshot,'{club,logo_url}',coalesce(to_jsonb(kombax_documents.club_logo(new.club_id)),'null'::jsonb),true);return new;end $$;
create or replace function public.app_receipt_public_logo_r104() returns trigger language plpgsql security definer set search_path='' as $$
begin new.emisor_logo_url:=kombax_documents.club_logo(new.club_id);return new;end $$;
CREATE OR REPLACE FUNCTION public.app_kombax_evento_entidades_v160(p_evento_id uuid)
 RETURNS TABLE(id uuid, rol text, origen text, social_profile_id uuid, nombre text, slug text, perfil_tipo text, logo_url text, web_url text, verificado boolean, puede_gestionar boolean, estado text, orden smallint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_manage boolean:=false;v_view boolean:=false;
begin
 if auth.uid() is not null then v_manage:=public.app_kombax_evento_puede_gestionar_v160(p_evento_id);end if;
 v_view:=public.app_kombax_event_can_view_v236(p_evento_id);
 if not v_manage and not v_view then return;end if;
 return query select ee.id,ee.rol,ee.origen,ee.social_profile_id,case when ee.origen='kombax' then sp.nombre_publico else ee.nombre_externo end,case when ee.origen='kombax' then sp.slug else null end,case when ee.origen='kombax' then public.app_kombax_social_tipo_v051(sp.id) else 'externa' end,case when ee.origen='kombax' and sp.sujeto_tipo='club' then kombax_documents.club_logo(sp.club_id) when ee.origen='kombax' then public.app_kombax_social_avatar_url_v063(sp.id) else ee.logo_url_externo end,case when ee.origen='externa' then ee.web_externa else null end,case when ee.origen='kombax' then sp.verificado else false end,ee.puede_gestionar,ee.estado,ee.orden from public.kombax_evento_entidades ee left join public.kombax_social_perfiles sp on sp.id=ee.social_profile_id where ee.evento_id=p_evento_id and (ee.estado='aceptada' or v_manage) order by case ee.rol when 'organizador_principal' then 0 when 'organizador' then 1 when 'coorganizador' then 2 when 'avala' then 3 when 'colaborador' then 4 when 'patrocinador_principal' then 5 when 'patrocinador_oficial' then 6 else 7 end,ee.orden,ee.creado_en;
end $function$
;
CREATE OR REPLACE FUNCTION public.app_kombax_report_payload_r77(p_scope text, p_subject_id uuid, p_report_type text, p_days integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_scope text := lower(coalesce(p_scope,''));
  v_type text := lower(coalesce(p_report_type,'general'));
  v_analytics jsonb;
  v_entity jsonb;
  v_extra jsonb := '{}'::jsonb;
  v_event public.kombax_eventos_publicos;
  v_provider public.kombax_showcase_marcas;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_scope='showcase' then
    if not kombax_payments.can_manage_provider(v_uid,p_subject_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
    if v_type not in ('general','sales','finance','products','stock','orders','performance') then raise exception 'REPORT_TYPE_INVALID'; end if;
    select * into strict v_provider from public.kombax_showcase_marcas where id=p_subject_id;
    v_analytics:=public.app_kombax_showcase_analytics_r77(p_subject_id,p_days);
    v_entity:=jsonb_build_object(
      'id',v_provider.id,'name',v_provider.nombre,'type',v_provider.sujeto_tipo,
      'logo_url',coalesce(v_provider.logo_url,(select c.logo_url from public.clubes c where c.id=v_provider.club_id)),
      'club_id',v_provider.club_id
    );
    v_extra:=jsonb_build_object(
      'finance',public.app_kombax_showcase_finance_r65(p_subject_id),
      'inventory',(select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'name',e.nombre,'image_url',e.imagen_url,'status',e.estado,'stock',e.stock,'stock_alert_threshold',e.stock_alert_threshold,'product_type',e.product_type,'price',e.precio_venta) order by e.nombre),'[]'::jsonb) from public.kombax_showcase_elementos e where e.marca_id=p_subject_id and e.listing_kind='product'),
      'orders',(select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (select o.id,o.order_number,o.amount_total_minor,o.currency,o.status,o.created_at,o.shipped_at,o.delivered_at,(select coalesce(sum(i.quantity),0)::int from kombax_payments.showcase_order_items i where i.order_id=o.id) units from kombax_payments.showcase_orders o where o.seller_provider_id=p_subject_id order by o.created_at desc limit 200) x)
    );
  elsif v_scope='event' then
    if not kombax_payments.can_manage_event_r65(v_uid,p_subject_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
    if v_type not in ('general','sales','finance','tickets','attendance','participants','fights','results','executive') then raise exception 'REPORT_TYPE_INVALID'; end if;
    select * into strict v_event from public.kombax_eventos_publicos where id=p_subject_id;
    v_analytics:=public.app_kombax_event_analytics_r77(p_subject_id,p_days);
    v_entity:=jsonb_build_object(
      'id',v_event.id,'name',v_event.nombre,'type','event','organizer',v_event.organizador_nombre,
      'logo_url',kombax_documents.event_logo(v_event.id),
      'poster_url',v_event.cartel_url,'date',v_event.fecha_inicio,'venue',v_event.lugar_nombre,'city',v_event.municipio,'country',v_event.pais
    );
    v_extra:=jsonb_build_object(
      'finance',public.app_kombax_event_finance_r65(p_subject_id),
      'results',(select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('co_estelar',f.co_estelar) order by r.destacado desc,f.co_estelar desc,r.orden nulls last),'[]'::jsonb) from public.app_kombax_evento_resultados_v164(p_subject_id) r join public.kombax_evento_combates_publicos f on f.id=r.id),
      'participants',(select coalesce(jsonb_agg(to_jsonb(p)),'[]'::jsonb) from public.app_kombax_evento_participantes_v161(p_subject_id) p),
      'ticket_orders',(select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (select o.id,o.order_number,o.quantity,o.amount_total_minor,o.currency,o.status,o.paid_at,o.refunded_at,o.created_at,o.refund_state from kombax_payments.event_ticket_orders o where o.event_id=p_subject_id order by o.created_at desc limit 250) x),
      'attendance',(select jsonb_build_object('issued',count(*),'active',count(*) filter(where status='active'),'used',count(*) filter(where status='used'),'refunded',count(*) filter(where status='refunded'),'cancelled',count(*) filter(where status='cancelled')) from kombax_payments.event_tickets where event_id=p_subject_id)
    );
  else
    raise exception 'REPORT_SCOPE_INVALID';
  end if;
  return jsonb_build_object('ok',true,'scope',v_scope,'report_type',v_type,'days',least(greatest(coalesce(p_days,30),1),365),'generated_at',now(),'entity',v_entity,'analytics',v_analytics,'extra',v_extra);
end $function$
;
revoke all on all functions in schema kombax_documents from public,anon,authenticated;
revoke all on function public.app_finance_report_public_logo_r104(),public.app_receipt_public_logo_r104() from public,anon,authenticated;
commit;
