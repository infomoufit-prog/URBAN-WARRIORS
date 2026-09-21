-- KOMBAX 20.110 R60 PILOT FINAL · public QA cleanup and least-privilege helper surface.
begin;

-- Internal QA identities remain available to administrators/test tooling but are no longer
-- discoverable in the public Social directory during the pilot.
update public.kombax_social_perfiles
set visible=false
where nombre_publico in (
  'FEDERACIÓN KOMBAX QA · DEMO',
  'NORA VEGA · COMPETIDORA QA',
  'QA-CLUB-001 · KOMBAX QA TEST'
)
and visible=true;

-- This helper is consumed only by SECURITY DEFINER entry points. It is intentionally not
-- exposed as a standalone authenticated RPC.
revoke execute on function public.app_kombax_social_network_actor_allowed_v255(uuid) from authenticated;

notify pgrst,'reload schema';
commit;
