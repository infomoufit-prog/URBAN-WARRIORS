do $$ begin
 if to_regclass('public.kombax_evento_media') is null then raise exception 'VERIFY_165: tabla media'; end if;
 if not exists(select 1 from storage.buckets where id='kombax-events-media' and public=false) then raise exception 'VERIFY_165: bucket privado'; end if;
 if to_regprocedure('public.app_kombax_evento_media_v165(uuid)') is null then raise exception 'VERIFY_165: media rpc'; end if;
end $$;
