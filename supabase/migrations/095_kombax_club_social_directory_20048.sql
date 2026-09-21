-- KOMBAX RC13 build 20048 · Club Community resolves people to canonical KOMBAX Social profiles.
begin;

create or replace function public.app_kombax_club_social_directory_v095(
  p_club_id uuid,
  p_query text default '',
  p_limit integer default 100
)
returns table(
  social_id uuid,
  socio_id uuid,
  tipo text,
  nombre_publico text,
  apodo_deportivo text,
  avatar_url text,
  affiliation_confirmed boolean
)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_q text:=lower(btrim(coalesce(p_query,'')));
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if p_club_id is null then raise exception 'CLUB_REQUIRED';end if;
  if not public.es_miembro_club(p_club_id) and not public.app_kombax_es_platform_admin_v055() then raise exception 'CLUB_MEMBERSHIP_REQUIRED';end if;
  return query
  with rows as (
    select sp.id social_id,null::uuid socio_id,'club'::text tipo,sp.nombre_publico,null::text apodo_deportivo,
      public.app_kombax_social_avatar_url_v063(sp.id) avatar_url,true affiliation_confirmed,0 ord
    from public.kombax_social_perfiles sp
    where sp.sujeto_tipo='club' and sp.club_id=p_club_id and sp.estado='activo' and sp.visible
    union all
    select sp.id,i.socio_origen_id,'miembro'::text,sp.nombre_publico,i.apodo_deportivo,
      public.app_kombax_social_avatar_url_v063(sp.id),
      exists(select 1 from public.socios s where s.id=i.socio_origen_id and s.club_id=i.club_origen_id and s.estado='activo') affiliation_confirmed,1 ord
    from public.identidades_sociales i
    join public.kombax_social_perfiles sp on sp.sujeto_tipo='miembro' and sp.identidad_social_id=i.id
    where i.club_origen_id=p_club_id and i.estado='activa' and sp.estado='activo' and sp.visible
  )
  select r.social_id,r.socio_id,r.tipo,r.nombre_publico,r.apodo_deportivo,r.avatar_url,r.affiliation_confirmed
  from rows r
  where v_q='' or lower(coalesce(r.nombre_publico,'')) like '%'||v_q||'%' or lower(coalesce(r.apodo_deportivo,'')) like '%'||v_q||'%'
  order by r.ord,r.nombre_publico
  limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_club_social_directory_v095(uuid,text,integer) from public,anon;
grant execute on function public.app_kombax_club_social_directory_v095(uuid,text,integer) to authenticated;

comment on function public.app_kombax_club_social_directory_v095(uuid,text,integer) is 'Canonical same-club directory for Community UI. Returns KOMBAX Social IDs; never Relations or private club records.';
notify pgrst,'reload schema';
commit;
