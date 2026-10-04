-- FIX11: keep full profile descriptions; the Social preview bio has its own 800-character limit.
do $patch$
declare d text; proc regprocedure;
begin
 foreach proc in array array[
   'public.app_kombax_social_sync_directo_v041()'::regprocedure,
   'public.app_kombax_social_sync_club_public_v051()'::regprocedure
 ] loop
 select pg_get_functiondef(proc) into d;
 if strpos(d,'new.descripcion')=0 then raise exception 'FIX11_SOCIAL_DESCRIPTION_ANCHOR_MISSING';end if;
 d:=replace(d,'new.descripcion','left(new.descripcion,800)');
 execute d;
 end loop;
end $patch$;
notify pgrst,'reload schema';
