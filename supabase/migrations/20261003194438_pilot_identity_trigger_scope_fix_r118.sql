-- R118 FIX02: shared triggers must only resolve NEW fields for their table.
-- PostgreSQL may resolve every field in an AND expression before evaluating it.
begin;
create or replace function public.app_kombax_account_identity_guard_r100()
returns trigger language plpgsql security definer set search_path='public','auth'
as $function$
declare v_uid uuid:=new.perfil_id; v_type text:=new.tipo; v_identity uuid;
begin
 if v_uid is null then return new; end if;
 if tg_table_name='kombax_solicitudes_alta' then
  if new.perfil_directo_id is not null then
   if not exists(select 1 from public.perfiles_kombax_directos d
     where d.id=new.perfil_directo_id and d.perfil_id=v_uid and d.tipo=v_type) then
    raise exception 'KOMBAX_PROFILE_APPLICATION_MISMATCH';
   end if;
  end if;
 elsif tg_table_name='perfiles_kombax_directos' then
  if v_type in ('competidor','profesional','espectador') and new.origen_identidad_social_id is null then
   select i.id into v_identity from public.identidades_sociales i
    where i.perfil_id=v_uid order by i.activada_en limit 1;
   if v_identity is not null then new.origen_identidad_social_id:=v_identity; end if;
  end if;
 end if;
 -- Compatible facets remain permitted; application ownership remains checked.
 return new;
end $function$;
notify pgrst,'reload schema';
commit;
