-- FIX11: canonicalize optional Club public links without changing pilot eligibility.
create or replace function public.app_kombax_club_public_link_r119(p_value text,p_network text default 'web')
returns text language plpgsql immutable security invoker set search_path='' as $$
declare v text:=btrim(coalesce(p_value,'')); n text:=lower(p_network); h text;
begin
 if v='' then return null; end if;
 if char_length(v)>500 or v ~ '[[:space:]\\]' then raise exception 'KOMBAX_CLUB_PUBLIC_LINK_INVALID'; end if;
 if v ~* '^http://' then v:='https://'||substr(v,8); end if;
 if v ~* '^https://' then
   if v !~* '^https://[a-z0-9]([a-z0-9.-]*[a-z0-9])?\.[a-z]{2,}(:[0-9]{1,5})?([/?#][^[:space:]]*)?$'
   then raise exception 'KOMBAX_CLUB_PUBLIC_LINK_INVALID'; end if;
 elsif v ~* '^(www\.)?[a-z0-9][a-z0-9.-]*\.[a-z]{2,}([/?#].*)?$' then v:='https://'||v;
 else
   h:=regexp_replace(v,'^@','');
   if n='instagram' and h ~ '^[a-zA-Z0-9._]{1,30}$' then v:='https://www.instagram.com/'||h||'/';
   elsif n='tiktok' and h ~ '^[a-zA-Z0-9._]{1,24}$' then v:='https://www.tiktok.com/@'||h;
   elsif n='youtube' and h ~ '^[a-zA-Z0-9._-]{3,30}$' then v:='https://www.youtube.com/@'||h;
   else raise exception 'KOMBAX_CLUB_PUBLIC_LINK_INVALID'; end if;
 end if;
 if char_length(v)>(case when n in ('instagram','tiktok') then 240 else 500 end) then raise exception 'KOMBAX_CLUB_PUBLIC_LINK_INVALID'; end if;
 return v;
end $$;
revoke all on function public.app_kombax_club_public_link_r119(text,text) from public,anon,authenticated;
grant execute on function public.app_kombax_club_public_link_r119(text,text) to service_role;

do $patch$
declare d text; anchor text:='  if p_manager_perfil_id is null';
begin
 select pg_get_functiondef('public.app_kombax_create_pilot_club_core_r117(uuid,text,jsonb,jsonb,uuid)'::regprocedure) into d;
 if strpos(d,anchor)=0 then raise exception 'FIX11_CORE_PATCH_ANCHOR_MISSING'; end if;
 if strpos(d,'app_kombax_club_public_link_r119')=0 then
 d:=replace(d,anchor,$code$
  if char_length(coalesce(v_public->>'descripcion',''))>1200 then raise exception 'KOMBAX_CLUB_DESCRIPTION_TOO_LONG'; end if;
  v_public:=v_public||jsonb_build_object(
    'web_publica',public.app_kombax_club_public_link_r119(v_public->>'web_publica','web'),
    'instagram',public.app_kombax_club_public_link_r119(v_public->>'instagram','instagram'),
    'tiktok',public.app_kombax_club_public_link_r119(v_public->>'tiktok','tiktok'),
    'youtube',public.app_kombax_club_public_link_r119(v_public->>'youtube','youtube'));
$code$||anchor);
 d:=replace(d,'descripcion=left(nullif(btrim(v_public->>''descripcion''),''''),1600)','descripcion=left(nullif(btrim(v_public->>''descripcion''),''''),1200)');
 d:=replace(d,'instagram=left(nullif(btrim(v_public->>''instagram''),''''),180)','instagram=left(nullif(btrim(v_public->>''instagram''),''''),240)');
 d:=replace(d,'tiktok=left(nullif(btrim(v_public->>''tiktok''),''''),180)','tiktok=left(nullif(btrim(v_public->>''tiktok''),''''),240)');
 d:=replace(d,'youtube=left(nullif(btrim(v_public->>''youtube''),''''),180)','youtube=left(nullif(btrim(v_public->>''youtube''),''''),500)');
 execute d;
 end if;
end $patch$;
notify pgrst,'reload schema';
