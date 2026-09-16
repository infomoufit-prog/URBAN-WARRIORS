# KOMBAX 20.101 R51 — Video Covers & Album Framing

Base congelada: R50 final.

## Alcance cerrado
- KOMBAX Social y KOMBAX Events: portada configurable de vídeo.
- Modos de portada: automática, fotograma elegido, imagen propia.
- Portada independiente del MP4; reemplazarla no modifica ni recomprime el vídeo.
- Álbumes: Completo / Equilibrado / Rellenar para fotos y vídeos.
- Original siempre preservado; fullscreen usa contenido completo.
- Mantener R50: 16:9 horizontal, 9:16 vertical, 1:1 cuadrado; vídeo HD hasta 1080p, 60 s y 100 MB.
- Unificar álbum de miembro/perfil, Club, perfiles directos y KOMBAX Events.
- Mantener nombres de producto KOMBAX Social / KOMBAX Events.

## Backend
Migración: `245_kombax_video_covers_album_framing_r51.sql`.
Live: `20260905133440 kombax_video_covers_album_framing_r51`.
Edge Function: `event-media-url` v2, compatible con asset histórico y variante cover.

## Criterios de cierre
- R51 focal PASS.
- suite completa PASS.
- build web/dist/Android con paridad exacta.
- secret scan sin credenciales privadas incrustadas.
- ZIP íntegro y smoke desde extracción limpia.
