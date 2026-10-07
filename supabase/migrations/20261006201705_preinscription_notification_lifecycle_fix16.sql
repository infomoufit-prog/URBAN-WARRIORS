-- FIX16: scoped notification lifecycle transition during pre-enrollment decisions.
begin;
CREATE OR REPLACE FUNCTION private.kombax_preinscripcion_notification_sync_r117()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  previous_gateway text := coalesce(current_setting('kombax.lifecycle_gateway',true),'');
begin
  if tg_op='INSERT' or old.estado is distinct from new.estado then
    perform set_config('kombax.lifecycle_gateway','on',true);
    if new.estado in ('enviada','en_revision','pendiente_documentacion') then
      insert into public.notificaciones(
        club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
      )
      select
        new.club_id,rol,
        'preinscripcion-'||new.id||'-'||rol::text,
        'inscripcion','Nueva preinscripción',
        trim(concat_ws(' ',new.nombre,new.apellidos))||' ha enviado una solicitud.',
        'enrollments',
        jsonb_build_object('preinscripcion_id',new.id,'self_service',new.solicitante_perfil_id is not null),
        case when exists(select 1 from public.perfiles p where p.id=auth.uid()) then auth.uid() else null end
      from unnest(array['direccion','secretaria']::public.rol_club[]) rol
      on conflict(club_id,rol_destino,clave)
      where clave is not null and rol_destino is not null
      do update set
        titulo=excluded.titulo,cuerpo=excluded.cuerpo,ruta=excluded.ruta,datos=excluded.datos,
        ciclo_estado='activo',archivado_en=null,archivado_por=null,papelera_en=null,papelera_por=null;
    else
      update public.notificaciones n
      set ciclo_estado='archivado',archivado_en=coalesce(n.archivado_en,now()),
          leida=true,leida_en=coalesce(n.leida_en,now())
      where n.club_id=new.club_id
        and n.ciclo_estado='activo'
        and n.datos->>'preinscripcion_id'=new.id::text
        and n.rol_destino is not null;
    end if;
  end if;
  perform set_config('kombax.lifecycle_gateway',previous_gateway,true);
  return new;
exception when others then
  perform set_config('kombax.lifecycle_gateway',previous_gateway,true);
  raise;
end
$function$
;
revoke all on function private.kombax_preinscripcion_notification_sync_r117() from public, anon, authenticated;
commit;
