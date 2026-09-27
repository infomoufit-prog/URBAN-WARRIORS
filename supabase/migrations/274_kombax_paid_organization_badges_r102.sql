-- R102: the badge represents a verified competitor or a paid, verified organization.
-- Pilot benefits, trial subscriptions and manually activated plans without payment
-- evidence grant product access but do not claim payment or a verification badge.
begin;

create or replace function public.app_kombax_subscription_paid_v102(p_subject_type text,p_subject_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists (
    select 1 from public.kombax_suscripciones s
    where s.sujeto_tipo=p_subject_type and s.sujeto_id=p_subject_id
      and s.estado='activa' and s.modalidad is not null
      and s.proveedor in ('stripe','stripe_billing','kombax_manual_paid')
      and nullif(btrim(s.referencia_externa),'') is not null
      and (s.inicia_en is null or s.inicia_en<=now())
      and (s.termina_en is null or s.termina_en>now())
  );
$$;
revoke all on function public.app_kombax_subscription_paid_v102(text,uuid) from public,anon,authenticated;

create or replace function public.app_kombax_badge_tipo_v069(p_social_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select case
    when sp.sujeto_tipo='club' and c.activo
      and public.app_kombax_subscription_paid_v102('club',sp.club_id) then 'club'
    when sp.sujeto_tipo='perfil_directo' and d.tipo='competidor'
      and d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited')
      and d.estado='activo' then 'competidor'
    when sp.sujeto_tipo='perfil_directo' and d.tipo in ('marca','federacion')
      and d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited')
      and d.estado='activo'
      and public.app_kombax_subscription_paid_v102('perfil_directo',d.id) then d.tipo
    else null end
  from public.kombax_social_perfiles sp
  left join public.clubes c on c.id=sp.club_id
  left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  where sp.id=p_social_id;
$$;

create or replace function public.app_kombax_social_badge_guard_v069()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_valid boolean:=false;
begin
  if new.sujeto_tipo='club' then
    v_valid:=exists(select 1 from public.clubes c where c.id=new.club_id and c.activo)
      and public.app_kombax_subscription_paid_v102('club',new.club_id);
  elsif new.sujeto_tipo='perfil_directo' and new.perfil_directo_id is not null then
    v_valid:=exists(
      select 1 from public.perfiles_kombax_directos d
      where d.id=new.perfil_directo_id and d.estado='activo'
        and d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited')
        and (d.tipo='competidor' or
          (d.tipo in ('marca','federacion') and public.app_kombax_subscription_paid_v102('perfil_directo',d.id)))
    );
  end if;
  new.verificado:=coalesce(v_valid,false);
  return new;
end $$;
revoke all on function public.app_kombax_social_badge_guard_v069() from public,anon,authenticated;

create or replace function public.app_kombax_refresh_subscription_badge_v102()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_subject_type text;v_subject_id uuid;
begin
  if tg_op='DELETE' then v_subject_type:=old.sujeto_tipo;v_subject_id:=old.sujeto_id;
  else v_subject_type:=new.sujeto_tipo;v_subject_id:=new.sujeto_id;end if;
  update public.kombax_social_perfiles sp
  set verificado=(public.app_kombax_badge_tipo_v069(sp.id) is not null),actualizado_en=now()
  where (v_subject_type='club' and sp.sujeto_tipo='club' and sp.club_id=v_subject_id)
     or (v_subject_type='perfil_directo' and sp.sujeto_tipo='perfil_directo' and sp.perfil_directo_id=v_subject_id);
  return null;
end $$;
revoke all on function public.app_kombax_refresh_subscription_badge_v102() from public,anon,authenticated;
drop trigger if exists kombax_subscription_badge_refresh_v102 on public.kombax_suscripciones;
create trigger kombax_subscription_badge_refresh_v102
after insert or update or delete on public.kombax_suscripciones
for each row execute function public.app_kombax_refresh_subscription_badge_v102();

update public.kombax_social_perfiles sp
set verificado=(public.app_kombax_badge_tipo_v069(sp.id) is not null),actualizado_en=now()
where sp.verificado is distinct from (public.app_kombax_badge_tipo_v069(sp.id) is not null);

notify pgrst,'reload schema';
commit;
