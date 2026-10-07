do $fix$ declare d text;begin
select pg_get_functiondef('public.app_mutate_v160_pre_lifecycle_133(text,jsonb,uuid)'::regprocedure) into d;
if position('c.slug=slug and lower(i.email)' in d)>0 then execute replace(d,'c.slug=slug and lower(i.email)','c.slug=trim(coalesce(payload->>''club_slug'','''')) and lower(i.email)');end if;
end $fix$;
