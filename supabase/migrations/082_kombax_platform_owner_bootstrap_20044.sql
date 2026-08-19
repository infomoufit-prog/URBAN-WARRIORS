-- KOMBAX RC13 build 20044 · 082 · bootstrap auditable del propietario global.
-- Resuelve la cuenta maestra por email; no hardcodea UUIDs generados.
begin;

do $bootstrap$
declare
  v_email text:='infomoufit@gmail.com';
  v_profile_id uuid;
  v_count integer;
begin
  select count(*), (array_agg(p.id order by p.id::text))[1]
    into v_count,v_profile_id
  from auth.users u
  join public.perfiles p on p.id=u.id
  where lower(u.email)=lower(v_email);

  if v_count<>1 or v_profile_id is null then
    raise exception 'KOMBAX_PLATFORM_OWNER_ACCOUNT_NOT_UNIQUE';
  end if;

  insert into public.kombax_platform_admins(perfil_id,nivel,activo,asignado_por,motivo,creado_en,actualizado_en)
  values(v_profile_id,'owner',true,v_profile_id,'Bootstrap propietario global KOMBAX aprobado por el titular de la plataforma',now(),now())
  on conflict(perfil_id) do update set
    nivel='owner',activo=true,asignado_por=excluded.asignado_por,motivo=excluded.motivo,actualizado_en=now();
end
$bootstrap$;

commit;
