-- Add validation to the existing Club publication guard; keep authorized pilots.
-- No new function and no subscription requirement for Social publication.
do $guard$
declare definition text; old_clause text := 'and public.app_kombax_club_permiso_v051(sp.club_id,''social.act_as_club''))';
begin
 select pg_get_functiondef('public.app_kombax_social_puede_actuar_v051(uuid)'::regprocedure) into definition;
 if position(old_clause in definition)=0 then raise exception 'FIX19_SOCIAL_GUARD_SOURCE_MISMATCH';end if;
 execute replace(definition,old_clause,$replacement$and public.app_kombax_club_permiso_v051(sp.club_id,'social.act_as_club')
        and (
          exists(select 1 from public.kombax_solicitudes_alta a where a.club_id=sp.club_id and a.tipo='club' and a.estado='verified')
          or exists(select 1 from kombax_commercial.pilot_club_activations_r110 pilot where pilot.club_id=sp.club_id and pilot.activation_status='active')
        ))$replacement$);
end $guard$;
