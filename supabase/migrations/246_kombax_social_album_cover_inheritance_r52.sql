-- KOMBAX 20.101 R52 · Herencia segura de portada/encuadre al publicar multimedia de álbum en KOMBAX Social.
-- Corrige el caso R51 en el que Club/Perfil Directo generaban correctamente la portada en su álbum,
-- pero la referencia social creada mediante kombax.social.media.from_album nacía con media_presentation vacío.
begin;

create or replace function public.app_kombax_social_media_inherit_album_presentation_v252()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_p jsonb;
begin
  if coalesce(new.media_presentation,'{}'::jsonb) <> '{}'::jsonb then return new; end if;

  select cm.media_presentation into v_p
  from public.kombax_club_media cm
  where cm.storage_path=new.storage_path and cm.estado='active'
    and coalesce(cm.media_presentation,'{}'::jsonb) <> '{}'::jsonb
  order by cm.actualizado_en desc nulls last,cm.creado_en desc
  limit 1;

  if coalesce(v_p,'{}'::jsonb)='{}'::jsonb then
    select pm.media_presentation into v_p
    from public.kombax_perfil_media pm
    where pm.storage_path=new.storage_path and pm.estado='active'
      and coalesce(pm.media_presentation,'{}'::jsonb) <> '{}'::jsonb
    order by pm.actualizado_en desc nulls last,pm.creado_en desc
    limit 1;
  end if;

  if coalesce(v_p,'{}'::jsonb) <> '{}'::jsonb then
    new.media_presentation:=public.app_kombax_media_presentation_normalize_v187(v_p);
  end if;
  return new;
end $$;

revoke all on function public.app_kombax_social_media_inherit_album_presentation_v252() from public,anon,authenticated;

drop trigger if exists trg_kombax_social_media_inherit_album_presentation_r52 on public.kombax_social_media;
create trigger trg_kombax_social_media_inherit_album_presentation_r52
before insert on public.kombax_social_media
for each row execute function public.app_kombax_social_media_inherit_album_presentation_v252();

-- Backfill genérico: solo referencias Social vacías que comparten exactamente el asset de un álbum válido.
-- El guard histórico exige auth.uid() en UPDATE, por lo que se desactiva únicamente durante esta reparación transaccional.
alter table public.kombax_social_media disable trigger kombax_social_media_guard_v053;
update public.kombax_social_media sm
set media_presentation=public.app_kombax_media_presentation_normalize_v187(
  coalesce(
    nullif((select cm.media_presentation from public.kombax_club_media cm where cm.storage_path=sm.storage_path and cm.estado='active' and coalesce(cm.media_presentation,'{}'::jsonb)<>'{}'::jsonb order by cm.actualizado_en desc nulls last,cm.creado_en desc limit 1),'{}'::jsonb),
    nullif((select pm.media_presentation from public.kombax_perfil_media pm where pm.storage_path=sm.storage_path and pm.estado='active' and coalesce(pm.media_presentation,'{}'::jsonb)<>'{}'::jsonb order by pm.actualizado_en desc nulls last,pm.creado_en desc limit 1),'{}'::jsonb),
    '{}'::jsonb
  )
)
where coalesce(sm.media_presentation,'{}'::jsonb)='{}'::jsonb
  and (
    exists(select 1 from public.kombax_club_media cm where cm.storage_path=sm.storage_path and cm.estado='active' and coalesce(cm.media_presentation,'{}'::jsonb)<>'{}'::jsonb)
    or exists(select 1 from public.kombax_perfil_media pm where pm.storage_path=sm.storage_path and pm.estado='active' and coalesce(pm.media_presentation,'{}'::jsonb)<>'{}'::jsonb)
  );
alter table public.kombax_social_media enable trigger kombax_social_media_guard_v053;

notify pgrst,'reload schema';
commit;
