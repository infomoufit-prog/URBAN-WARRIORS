-- Repair only the storage URL matcher; retain moderation, ownership and history guards.
do $fix$
declare v_definition text; v_bad text; v_good text;
begin
 select pg_get_functiondef('public.app_kombax_content_action_r118(text,uuid,text,text,jsonb,text)'::regprocedure) into v_definition;
 v_bad:='^https://poggsobhtutbuagjiydc'||repeat(chr(92),2)||'.supabase'||repeat(chr(92),2)||'.co/storage/v1/object/public/kombax-public-media/';
 v_good:='^https://poggsobhtutbuagjiydc'||chr(92)||'.supabase'||chr(92)||'.co/storage/v1/object/public/kombax-public-media/';
 if position(v_bad in v_definition)>0 then execute replace(v_definition,v_bad,v_good);
 elsif position(v_good in v_definition)=0 then raise exception 'UNEXPECTED_CONTENT_CLEANUP_DEFINITION'; end if;
 if not ('https://poggsobhtutbuagjiydc.supabase.co/storage/v1/object/public/kombax-public-media/qa.png' ~ v_good)
 or ('https://example.test/storage/v1/object/public/kombax-public-media/qa.png' ~ v_good) then raise exception 'CLEANUP_URL_MATCHER_INVALID'; end if;
end $fix$;
