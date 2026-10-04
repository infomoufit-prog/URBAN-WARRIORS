-- FIX11: the database enforces the same registration rules as the forms.
do $patch$
declare d text; anchor text;
begin
 select pg_get_functiondef('public.crear_perfil_usuario()'::regprocedure) into d;
 anchor:='  perform public.app_kombax_birth_date_validate_r117(v_dob);';
 if strpos(d,anchor)=0 then raise exception 'FIX11_SIGNUP_ANCHOR_MISSING';end if;
 d:=replace(d,anchor,$code$
  if public.app_kombax_birth_date_validate_r117(v_dob)<16 then raise exception 'KOMBAX_MINOR_MUST_USE_TUTOR_FLOW';end if;
  if new.raw_user_meta_data->>'tipo_cuenta'='tutor' and public.app_kombax_birth_date_validate_r117(v_dob)<18 then raise exception 'KOMBAX_TUTOR_MIN_AGE_18';end if;
$code$);
 execute d;
 select pg_get_functiondef('public.app_crear_preinscripcion(uuid,text,text,text,date,text,text,text,uuid,uuid,uuid,text,text)'::regprocedure) into d;
 anchor:='v_edad:=extract(year from age(current_date,p_fecha_nacimiento))::smallint;';
 if strpos(d,anchor)=0 then raise exception 'FIX11_ENROLLMENT_ANCHOR_MISSING';end if;
 d:=replace(d,anchor,'v_edad:=public.app_kombax_birth_date_validate_r117(p_fecha_nacimiento)::smallint;');
 execute d;
 select pg_get_functiondef('public.registrar_cuenta_club(text,text,text,text,text,date,text,text,date,uuid,uuid,uuid)'::regprocedure) into d;
 anchor:='  v_account_dob:=coalesce(p_fecha_nacimiento_adulto,v_account_dob);';
 if strpos(d,anchor)=0 then raise exception 'FIX11_CANONICAL_BIRTH_ANCHOR_MISSING';end if;
 d:=replace(d,anchor,$code$
  if v_account_dob is not null and p_fecha_nacimiento_adulto is not null and v_account_dob<>p_fecha_nacimiento_adulto then raise exception 'KOMBAX_ACCOUNT_BIRTH_DATE_INVALID';end if;
$code$||anchor);
 execute d;
end $patch$;
notify pgrst,'reload schema';
