begin;
drop function if exists public.app_kombax_social_mutate_v050(text,jsonb,uuid);
drop function if exists public.app_kombax_moderation_queue_v050(integer);
-- Rollback conservador: si ya existen denuncias de comentario no se estrecha el CHECK y no se destruye historial.
do $$
begin
  if not exists(select 1 from public.kombax_social_reportes where objetivo_tipo='comentario') then
    alter table public.kombax_social_reportes drop constraint if exists kombax_social_reportes_objetivo_tipo_check;
    alter table public.kombax_social_reportes add constraint kombax_social_reportes_objetivo_tipo_check check(objetivo_tipo in ('publicacion','perfil'));
  end if;
  if not exists(select 1 from public.kombax_social_moderacion where objetivo_tipo='comentario') then
    alter table public.kombax_social_moderacion drop constraint if exists kombax_social_moderacion_objetivo_tipo_check;
    alter table public.kombax_social_moderacion add constraint kombax_social_moderacion_objetivo_tipo_check check(objetivo_tipo in ('publicacion','perfil','reporte'));
  end if;
end $$;
notify pgrst,'reload schema';
commit;
