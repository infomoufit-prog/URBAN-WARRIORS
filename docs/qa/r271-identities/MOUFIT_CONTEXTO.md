# MOUFIT DEMO: estado Social y publicación

## Causa comprobada

`app_kombax_social_estado_v124` sobrescribía el resultado de club de v123 con el estado personal del administrador. En SQL se reprodujo: el mismo resultado contenía el ID Social del club y scope=person/status=inactiva. El club ya tenía su perfil público. No hacía falta crear ni borrar una identidad personal.

Además, MOUFIT DEMO no tenía solicitud verificada ni activación piloto. `publicar_habilitado=true` por sí solo no satisfacía la política de publicación. La edición Social del club dependía también de poder publicar, en contradicción con el acceso de administración al perfil público.

## Cambios

- El endpoint conserva el contexto del club si el usuario tiene permiso de representarlo y el perfil está activo.
- Editar el perfil público del club usa el permiso de gestión existente, sin conceder publicación por esa vía.
- Se habilita exclusivamente CLUB MOUFIT DEMO mediante tabla privada de autorización demo, por autorización expresa del usuario. No consume plaza piloto, no marca verificación documental ni habilita otros clubes.
- El aviso de activación del frontend toma el estado de la identidad seleccionada, evitando pedir un perfil personal cuando se opera con una organización activa.
- No se ha eliminado, creado ni fusionado ningún perfil de usuario u organización.

## Pruebas

19 comprobaciones aisladas con PGlite, usando las definiciones anteriores de los tres endpoints: reproduce el fallo, contexto correcto, publicación y edición demo, verificación sin cambios, cero plazas consumidas por demo, otro club sin verificar sigue bloqueado, alumno y tercero no publican como club, revocación y repetición de migración.

En Supabase real, contexto de administración titular: scope=club, status=activa, publication_enabled=true, management_enabled=true, album_enabled=true; verificado sigue false y plazas piloto activas siguen 3. Con contexto de alumno: no publica ni edita el perfil del club, scope=member. La tabla privada no es legible por authenticated.

No había sesión web abierta disponible en el navegador conectado. No se ha publicado contenido real ni se ha completado una prueba de publicación desde navegador con la sesión del usuario. Se debe volver a entrar a Social para recargar permisos; la corrección de backend usa los endpoints existentes. El ajuste visual requiere el frontend actualizado que incluye este ZIP.

La migración `20261014233134_social_club_status_context_r271.sql` ya está aplicada; no aplicar por segunda vez ni hacer db push indiscriminado. El archivo de reversión se conserva sin ejecutar.

Prueba adicional real del endpoint `app_kombax_social_mutate_v123`: una publicación QA transaccional fue aceptada con autor=perfil Club MOUFIT DEMO y estado activa dentro de la transacción. Se ejecutó ROLLBACK; no se conservó ni difundió contenido. No es una prueba de envío a Instagram.

Advisors: aparece el aviso informativo RLS sin políticas para la nueva tabla privada. Es deliberado: clientes anon/authenticated no tienen privilegios y solo el código privilegiado revisado consulta esa autorización. No se han añadido endpoints públicos; persisten avisos heredados de SECURITY DEFINER y contraseñas.

Versión registrada de la migración de contexto de club: `20261014233432`.
