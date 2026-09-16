# LIVE SUPABASE — R51

Proyecto verificado: `poggsobhtutbuagjiydc`.

## Migración viva
- `20260905133440 kombax_video_covers_album_framing_r51`

## Verificación
- Normalizador R51 acepta `fit=balanced`.
- Conserva `cover_mode`, `cover_time`, bucket/path/mime de portada.
- `cover_time` limitado por contrato de vídeo R50/R51.
- Normalizador interno no es ejecutable directamente por anon/authenticated.
- Resolver de media de evento conserva permisos históricos para asset y añade variante cover.

## Edge Function
`event-media-url` fue desplegada como versión 2.
- Mantiene compatibilidad pública histórica del endpoint.
- Añade `variant: cover`.
- Utiliza URL firmada para assets privados cuando corresponde.

No se insertó contenido ficticio en eventos reales para la comprobación.
