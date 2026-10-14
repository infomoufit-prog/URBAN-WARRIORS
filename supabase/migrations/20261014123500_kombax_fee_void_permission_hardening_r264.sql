-- Harden already deployed R264 function in case delegated access predicate is NULL.
-- Clean fresh installs should use the hardened expression in the main R264 migration.
do $$
declare src text; previous text:='if not public.tiene_rol_club(p_club_id,''direccion'',''economia'') then';
revised text:='if coalesce(public.tiene_rol_club(p_club_id,''direccion'',''economia''),false) is not true then';
begin
 select pg_get_functiondef(p.oid) into src
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='app_kombax_fee_void_r264';
 if src is null then raise exception 'R264_VOID_FUNCTION_MISSING'; end if;
 if strpos(src,revised)>0 then return;end if;
 if strpos(src,previous)=0 then raise exception 'R264_VOID_FUNCTION_BODY_UNEXPECTED';end if;
 execute replace(src,previous,revised);
end $$;
