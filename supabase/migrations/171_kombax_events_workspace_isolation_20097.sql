-- KOMBAX RC13 build 20.097 · 171 · Events workspace isolation
-- KOMBAX Eventos remains public/transversal, but management identity is scoped to the active workspace.
-- Never reads or migrates Mi Club > Eventos (eventos_competicion/evento_participantes/evento_combates).
begin;

create or replace function public.app_kombax_eventos_organizador_contexto_v171(p_club_id uuid)
returns table(
  social_profile_id uuid,sujeto_tipo text,sujeto_id uuid,perfil_tipo text,nombre_publico text,slug text,
  logo_url text,verificado boolean,puede_organizar boolean,motivo text
)
language sql stable security definer set search_path=public,auth as $$
  select sp.id,'club'::text,c.id,'club'::text,sp.nombre_publico,sp.slug,
         public.app_kombax_social_avatar_url_v063(sp.id),sp.verificado,
         public.app_kombax_eventos_sujeto_puede_organizar_v160('club',c.id),
         case
           when not exists(
             select 1 from public.kombax_entitlements e
             where e.sujeto_tipo='club' and e.sujeto_id=c.id and e.capacidad_clave='events.public.organize'
               and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())
           ) then 'Disponible con Club Premium o habilitación piloto'
           else ''
         end
  from public.clubes c
  join public.kombax_social_perfiles sp on sp.sujeto_tipo='club' and sp.club_id=c.id and sp.estado='activo' and sp.visible
  where c.id=p_club_id and c.activo and auth.uid() is not null
    and exists(
      select 1 from public.miembros_club m
      where m.club_id=c.id and m.perfil_id=auth.uid() and m.activo
        and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))
    );
$$;
revoke all on function public.app_kombax_eventos_organizador_contexto_v171(uuid) from public,anon;
grant execute on function public.app_kombax_eventos_organizador_contexto_v171(uuid) to authenticated;

create or replace function public.app_kombax_evento_contexto_gestion_v171(p_evento_id uuid,p_club_id uuid)
returns table(puede_gestionar boolean)
language sql stable security definer set search_path=public,auth as $$
  select coalesce(
    auth.uid() is not null
    and p_evento_id is not null
    and p_club_id is not null
    and public.app_kombax_eventos_sujeto_puede_organizar_v160('club',p_club_id)
    and (
      exists(
        select 1 from public.kombax_eventos_publicos e
        where e.id=p_evento_id and e.creador_tipo='club' and e.creador_club_id=p_club_id
      )
      or exists(
        select 1
        from public.kombax_evento_entidades ee
        join public.kombax_social_perfiles sp on sp.id=ee.social_profile_id
        where ee.evento_id=p_evento_id and ee.estado='aceptada' and ee.puede_gestionar
          and sp.sujeto_tipo='club' and sp.club_id=p_club_id and sp.estado='activo'
      )
    ),false
  );
$$;
revoke all on function public.app_kombax_evento_contexto_gestion_v171(uuid,uuid) from public,anon;
grant execute on function public.app_kombax_evento_contexto_gestion_v171(uuid,uuid) to authenticated;

create or replace function public.app_kombax_eventos_mutate_v171(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_workspace uuid;
  v_subject_type text:=lower(btrim(coalesce(v_payload->>'sujeto_tipo','')));
  v_subject_id uuid;
  v_event_id uuid;
  v_scoped boolean:=false;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_payload ? 'workspace_club_id' and nullif(v_payload->>'workspace_club_id','') is not null then
    v_workspace:=(v_payload->>'workspace_club_id')::uuid;
  end if;

  -- A club-created public event always requires an explicit active club workspace.
  if p_operation='event.save' then
    if nullif(v_payload->>'sujeto_id','') is not null then v_subject_id:=(v_payload->>'sujeto_id')::uuid; end if;
    if v_subject_type='club' then
      if v_workspace is null then raise exception 'EVENT_WORKSPACE_REQUIRED'; end if;
      if v_subject_id is distinct from v_workspace then raise exception 'EVENT_WORKSPACE_SUBJECT_MISMATCH'; end if;
    elsif v_subject_type='perfil_directo' and v_workspace is not null then
      raise exception 'EVENT_WORKSPACE_DIRECT_PROFILE_FORBIDDEN';
    end if;
  end if;

  -- Resolve event for privileged mutations and enforce the current club workspace when supplied.
  if v_workspace is not null and p_operation in (
    'event.save','event.entity.add','event.entity.remove','event.participant.status',
    'event.fight.save','event.fight.remove','event.fight.result.set',
    'event.media.register','event.media.update','event.media.remove'
  ) then
    if p_operation='event.save' and nullif(v_payload->>'id','') is not null then
      v_event_id:=(v_payload->>'id')::uuid;
    elsif p_operation in ('event.entity.add','event.fight.save','event.media.register') and nullif(v_payload->>'evento_id','') is not null then
      v_event_id:=(v_payload->>'evento_id')::uuid;
    elsif p_operation='event.entity.remove' and nullif(v_payload->>'entity_id','') is not null then
      select ee.evento_id into v_event_id from public.kombax_evento_entidades ee where ee.id=(v_payload->>'entity_id')::uuid;
    elsif p_operation='event.participant.status' and nullif(v_payload->>'participant_id','') is not null then
      select ep.evento_id into v_event_id from public.kombax_evento_participantes_publicos ep where ep.id=(v_payload->>'participant_id')::uuid;
    elsif p_operation in ('event.fight.remove','event.fight.result.set') and nullif(v_payload->>'fight_id','') is not null then
      select f.evento_id into v_event_id from public.kombax_evento_combates_publicos f where f.id=(v_payload->>'fight_id')::uuid;
    elsif p_operation in ('event.media.update','event.media.remove') and nullif(v_payload->>'media_id','') is not null then
      select m.evento_id into v_event_id from public.kombax_evento_media m where m.id=(v_payload->>'media_id')::uuid;
    end if;

    if p_operation='event.save' and v_event_id is null then
      -- New club event: subject/workspace match above + entitlement guard below is authoritative.
      select public.app_kombax_eventos_sujeto_puede_organizar_v160('club',v_workspace) into v_scoped;
    elsif v_event_id is not null then
      select x.puede_gestionar into v_scoped from public.app_kombax_evento_contexto_gestion_v171(v_event_id,v_workspace) x;
    end if;
    if not coalesce(v_scoped,false) then raise exception 'EVENT_WORKSPACE_MANAGEMENT_FORBIDDEN'; end if;
  end if;

  -- Preserve 20.094 result write-path hardening.
  if p_operation='event.fight.save' then
    v_payload:=v_payload - array['resultado','metodo_resultado','ganador_participante_id','asalto','tiempo_resultado','resultado_estado','notas_publicas'];
  end if;
  v_payload:=v_payload-'workspace_club_id';
  return public.app_kombax_eventos_mutate_v165(p_operation,v_payload,p_request_id);
end $$;
revoke all on function public.app_kombax_eventos_mutate_v171(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v171(text,jsonb,uuid) to authenticated;

comment on function public.app_kombax_eventos_organizador_contexto_v171(uuid) is '20.097: organizer context for one active club workspace only; never mixes direct Federation/Professional/Competitor identities.';
comment on function public.app_kombax_evento_contexto_gestion_v171(uuid,uuid) is '20.097: event management authorization scoped to an explicit club workspace.';
comment on function public.app_kombax_eventos_mutate_v171(text,jsonb,uuid) is '20.097: Events mutation gateway with explicit workspace isolation and 20.094 result hardening.';
notify pgrst,'reload schema';
commit;
