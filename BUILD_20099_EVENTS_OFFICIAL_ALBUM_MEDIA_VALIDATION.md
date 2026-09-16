# KOMBAX RC13 build 20.099 · Events Official Album + HD Media · Validación

## Objetivo
Evolucionar el multimedia de KOMBAX Eventos sin mezclarlo con Social ni con Mi Club: cada evento público dispone de un álbum oficial que acompaña el ciclo previo, durante y posterior al evento.

## Contrato funcional
- 15 fotos activas totales por evento.
- 5 vídeos almacenados activos por evento.
- Vídeo: MP4/WEBM/MOV, hasta 60 s, hasta 1080p y hasta 100 MB por archivo.
- Vídeos externos HTTPS: permitidos y separados de la cuota de almacenamiento.
- Fotos: JPG/PNG/WEBP, optimización cliente y máximo final 8 MB en el contrato backend.
- Retirar un elemento lo marca `retirado` y libera plaza de la cuota.
- Etiqueta temporal: `previo`, `evento` o `posterior`.

## UX
- gestor: carga múltiple de fotos y vídeos, secuencial y con estado de progreso;
- contador visible de plazas 0/15 y 0/5;
- álbum público en cuadrícula compacta (5 columnas desktop, 3 móvil);
- filtros Previo / Evento / Posterior;
- selección de miniatura abre lightbox grande;
- navegación anterior/siguiente y teclado Escape/←/→;
- vídeos conservan reproducción independiente y URLs firmadas temporales.

## Seguridad / backend
- Storage `kombax-events-media` permanece privado.
- bucket ampliado a 100 MB por objeto.
- reader `app_kombax_evento_media_v175` conserva aislamiento de workspace cuando hay club activo.
- cuota `app_kombax_evento_media_cuota_v175`: authenticated-only.
- write gateway `app_kombax_eventos_mutate_v175`: anon bloqueado.
- cuota 15/5 se impone en PostgreSQL.
- `pg_advisory_xact_lock` serializa las altas por evento para impedir carreras concurrentes.
- hardening 176 comprueba idempotencia por `request_id` antes de recalcular cuota.
- duración/resolución se inspeccionan en el cliente y el backend exige los metadatos declarados; no existe transcoder/ffprobe server-side en esta fase.

## Compatibilidad
- `prepareVideo()` conserva por defecto 15.2 s / 50 MB / 1080p para Comunidad y superficies históricas.
- solo KOMBAX Eventos invoca el perfil 60.2 s / 100 MB.
- 20.097 workspace isolation permanece intacto.
- 20.098 Large Format permanece intacto.
- Mi Club > Eventos continúa separado.

## Gates
- test específico 20.099: PASS.
- regresión histórica completa hasta 20.099: PASS.
- `npm run build`: PASS.
- `web = dist = Android`: 102 archivos idénticos.
- legal gate: PASS.
- Android preflight: 4/5; solo falta `android/keystore.properties` local con credenciales.
- JKS real incluido en `LOCAL_RELEASE_SIGNING/`; contraseñas no incluidas.

## Producción
- migración 175 aplicada a Supabase real.
- migración 176 aplicada a Supabase real.
- frontend 20.099 NO desplegada por esta intervención.
- health productivo NO debe anunciar 20099 hasta que el frontend 20.099 esté realmente desplegado.
