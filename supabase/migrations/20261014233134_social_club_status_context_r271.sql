begin;
-- Explicit demo authorization, separate from verified clubs and the four pilot slots.
create table if not exists private.kombax_social_demo_clubs_r271(
 club_id uuid primary key references public.clubes(id),
 active boolean not null default false,
 granted_at timestamptz not null default now(),
 reason text not null
);
alter table private.kombax_social_demo_clubs_r271 enable row level security;
revoke all on private.kombax_social_demo_clubs_r271 from public,anon,authenticated;
insert into private.kombax_social_demo_clubs_r271(club_id,active,reason)
select id,true,'Explicit owner authorization: MOUFIT demo Social publishing; no pilot quota or verification change.'
from public.clubes where id='11111111-1111-4111-8111-111111111111' and nombre='CLUB MOUFIT DEMO'
on conflict(club_id) do update set active=true,reason=excluded.reason;

do $$
declare old text; patched text;
begin
 select pg_get_functiondef('public.app_kombax_social_puede_actuar_v051(uuid)'::regprocedure) into old;
 if position('kombax_social_demo_clubs_r271' in old)=0 then
  patched:=replace(old,
   'or exists(select 1 from kombax_commercial.pilot_club_activations_r110 pilot where pilot.club_id=sp.club_id and pilot.activation_status=''active'')',
   'or exists(select 1 from kombax_commercial.pilot_club_activations_r110 pilot where pilot.club_id=sp.club_id and pilot.activation_status=''active'')
    or exists(select 1 from private.kombax_social_demo_clubs_r271 demo join public.clubes c on c.id=demo.club_id where demo.club_id=sp.club_id and demo.active and c.activo)');
  if patched=old then raise exception 'R271_DEMO_PUBLICATION_GUARD_CHANGED';end if;
  execute patched;
 end if;

 select pg_get_functiondef('public.app_kombax_social_puede_gestionar_perfil_publico_r117(uuid)'::regprocedure) into old;
 if position('app_puede_gestionar_perfil_club_v035' in old)=0 then
  patched:=replace(old,'or public.app_kombax_social_puede_actuar_v051(sp.id)',
   'or (sp.sujeto_tipo=''club'' and public.app_puede_gestionar_perfil_club_v035(sp.club_id))
    or public.app_kombax_social_puede_actuar_v051(sp.id)');
  if patched=old then raise exception 'R271_CLUB_MANAGEMENT_GUARD_CHANGED';end if;
  execute patched;
 end if;

 select pg_get_functiondef('public.app_kombax_social_estado_v124(uuid)'::regprocedure) into old;
 if position('R271_CLUB_CONTEXT' in old)=0 then
  patched:=replace(old,'if v_uid is null then return v; end if;',
   'if v_uid is null then return v; end if;
  -- R271_CLUB_CONTEXT: do not overwrite an authorized club with the account personal status.
  if p_club_id is not null and public.app_kombax_club_permiso_v051(p_club_id,''social.act_as_club'') then
   return coalesce((select v||jsonb_build_object(
    ''scope'',''club'',''status'',''activa'',''eligible'',true,''social_profile_id'',sp.id,
    ''publication_enabled'',public.app_kombax_social_puede_actuar_v051(sp.id),
    ''profile_enabled'',true,''album_enabled'',public.app_kombax_social_puede_gestionar_perfil_publico_r117(sp.id),
    ''reason'',''Puedes participar en KOMBAX Social utilizando la identidad pública del club.'')
    from public.kombax_social_perfiles sp where sp.club_id=p_club_id and sp.sujeto_tipo=''club'' and sp.estado=''activo'' and sp.visible order by sp.creado_en,sp.id limit 1),v);
  end if;');
  if patched=old then raise exception 'R271_CLUB_STATUS_ENDPOINT_CHANGED';end if;
  execute patched;
 end if;
end $$;
notify pgrst,'reload schema';
commit;
