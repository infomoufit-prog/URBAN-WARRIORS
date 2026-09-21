# Supabase · Auditoría KOMBAX Eventos Album 20.099

Proyecto: `poggsobhtutbuagjiydc`

## Migraciones aplicadas
- 175 `kombax_events_official_album_media_20099`
- 176 `kombax_events_album_idempotency_hardening_20099`

## Verificación live
Resultado confirmado:
- `momento`: presente;
- `duration_seconds`: presente;
- reader v175: anon/authenticated ejecutable;
- quota v175: anon bloqueado, authenticated permitido;
- mutate v175: anon bloqueado, authenticated permitido;
- bucket `kombax-events-media`: `public=false`;
- `file_size_limit=104857600` (100 MB).

## Límites
- foto activa almacenada: máximo 15 por `evento_id`;
- vídeo activo almacenado: máximo 5 por `evento_id`;
- vídeo externo no consume una plaza de vídeo almacenado;
- elementos `retirado` dejan de contar.

## Concurrencia e idempotencia
- advisory transaction lock por evento durante el alta;
- reintento con el mismo `request_id` devuelve el resultado persistido antes de recalcular cuotas.

## Privacidad
- objeto de Storage privado;
- publicación visual mediante signed URL de corta duración;
- lectura de media de gestión puede restringirse por `workspace_club_id` usando v171;
- no se consulta ni mezcla Mi Club > Eventos.

## Limitación conocida y explícita
PostgreSQL no inspecciona el stream de vídeo. La app obtiene duración/dimensiones del fichero real antes de subirlo y v175 exige/valida esos metadatos. Un futuro pipeline de transcodificación server-side podría verificar binariamente codec/duración si se necesitase un nivel antifraude adicional.
