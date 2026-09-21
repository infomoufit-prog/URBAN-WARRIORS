-- KOMBAX 20.112 R64 · Migrations organization guide compatibility for Brand
-- Extends the existing R60 guide/access contract without creating a parallel Migrations flow.
begin;

create or replace function public.app_kombax_org_guide_access_r60(p_tenant_ref text default null)
returns jsonb
language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_ctx record;
  v_allowed boolean:=false;
  v_kind text:=null;
  v_profile_type text:=null;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_tenant_ref);
  v_allowed:=kombax_ai_ops.migration_access_allowed(v_uid,v_ctx.tenant_ref);
  if v_allowed then
    if v_ctx.tenant_ref like 'club:%' then
      v_kind:='club';
    elsif v_ctx.tenant_ref like 'profile:%' then
      select lower(d.tipo) into v_profile_type
      from public.perfiles_kombax_directos d
      where d.id=replace(v_ctx.tenant_ref,'profile:','')::uuid and d.estado='activo';
      v_kind:=case when v_profile_type in('federacion','marca') then v_profile_type else null end;
    end if;
  end if;
  return jsonb_build_object(
    'allowed',v_allowed,
    'tenant_ref',v_ctx.tenant_ref,
    'organization_type',v_kind,
    'guide','KOMBAX_GUIA_MIGRACIONES_CLUB_FEDERACION_R60.pdf',
    'brand_catalog_migrations',v_kind='marca'
  );
end $$;
revoke all on function public.app_kombax_org_guide_access_r60(text) from public,anon,service_role;
grant execute on function public.app_kombax_org_guide_access_r60(text) to authenticated;
comment on function public.app_kombax_org_guide_access_r60(text) is
'R64 organization migration gate. Reuses the existing R60 guide and supports authorized Club, Federation and Brand contexts; Brand catalog/data imports are handled by the same Migrations engine.';

notify pgrst,'reload schema';
commit;
