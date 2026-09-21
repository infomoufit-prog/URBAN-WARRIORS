-- Verificación build 20038 · identidad/álbum/media.
select policyname,cmd,with_check from pg_policies where schemaname='storage' and tablename='objects' and policyname='kombax_club_media_insert_v046';
select to_regprocedure('public.app_kombax_social_avatar_url_v063(uuid)') is not null as avatar_url_helper,
       to_regprocedure('public.app_kombax_social_banner_url_v063(uuid)') is not null as banner_url_helper,
       to_regprocedure('public.app_kombax_social_feed_v053(timestamptz,uuid,integer)') is not null as feed_rpc,
       to_regprocedure('public.app_kombax_social_mis_perfiles_v051(uuid)') is not null as identities_rpc;
select sp.id,sp.nombre_publico,sp.avatar_url,pc.logo_url,
       public.app_kombax_social_avatar_url_v063(sp.id) as effective_avatar_url
from public.kombax_social_perfiles sp
left join public.perfiles_club_publicos pc on pc.club_id=sp.club_id
where sp.sujeto_tipo='club';
