do $fix$
declare d text;anchor text;replacement text;
begin
select pg_get_functiondef('public.app_mutate_v160_pre_lifecycle_133(text,jsonb,uuid)'::regprocedure) into d;
anchor:='if p_operation=''cuenta.registrar'' and code<>'''' then';
replacement:=anchor||$route$
    -- Personal pupil invitations keep their one-use, expiry and email checks.
    if exists(select 1 from public.invitaciones_club i
      join public.clubes c on c.id=i.club_id and c.activo
      join auth.users u on u.id=auth.uid() and u.email_confirmed_at is not null and u.deleted_at is null
      where upper(i.codigo)=upper(code) and i.tipo_invitacion='alumno'
      and c.slug=slug and lower(i.email)=lower(u.email)
      and lower(coalesce(auth.jwt()->>'email',''))=lower(u.email)) then
      return public.app_mutate_v160_pre_access_codes_060(p_operation,p_payload,p_request_id);
    end if;
$route$;
if position('-- Personal pupil invitations' in d)=0 then
if position(anchor in d)=0 then raise exception 'UNEXPECTED_FAMILY_CODE_GATEWAY';end if;
execute replace(d,anchor,replacement);
end if;
select pg_get_functiondef('public.app_mutate_v160_pre_access_codes_060(text,jsonb,uuid)'::regprocedure) into d;
anchor:='v_result:=public.app_mutate_v160_pre_invites_059(p_operation,v_payload,p_request_id);';
replacement:=anchor||'if coalesce((v_result->>''ok'')::boolean,false) is not true then return v_result;end if;';
if position(replacement in d)=0 then
if position(anchor in d)=0 then raise exception 'UNEXPECTED_PERSONAL_INVITE_GATEWAY';end if;
execute replace(d,anchor,replacement);
end if;
end $fix$;
