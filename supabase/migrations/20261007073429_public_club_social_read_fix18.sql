create or replace function public.app_kombax_social_acceso_v041() returns boolean
language sql stable security definer set search_path='public','auth' as $fn$
select auth.uid() is not null and (
 public.app_kombax_es_moderador_v041()
 or exists(select 1 from public.miembros_club m join public.kombax_entitlements e
  on e.sujeto_tipo='club' and e.sujeto_id=m.club_id and e.capacidad_clave='social.read'
  and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())
  where m.perfil_id=auth.uid() and m.activo)
 or exists(select 1 from public.perfiles_kombax_directos d join public.kombax_entitlements e
  on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id and e.capacidad_clave='social.read'
  and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())
  where d.perfil_id=auth.uid() and d.estado='activo')
 or exists(select 1 from public.kombax_social_perfiles sp
  left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  left join public.identidades_sociales i on i.id=sp.identidad_social_id
  where sp.visible and sp.estado='activo' and (
   (sp.sujeto_tipo='club' and exists(select 1 from public.miembros_club mc where mc.club_id=sp.club_id and mc.perfil_id=auth.uid() and mc.activo)) or
   (sp.sujeto_tipo='miembro' and i.perfil_id=auth.uid() and i.estado='activa')
   or (sp.sujeto_tipo='perfil_directo' and d.estado not in ('suspendido','cerrado')
    and d.moderacion_estado='normal' and (
     d.perfil_id=auth.uid() or exists(select 1 from public.kombax_perfil_gestores g
      where g.perfil_directo_id=d.id and g.perfil_id=auth.uid() and g.estado='activo')
    ))
  ))
);
$fn$;
