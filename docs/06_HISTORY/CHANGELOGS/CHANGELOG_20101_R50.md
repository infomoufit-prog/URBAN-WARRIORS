# KOMBAX 20.101 R50 — Media Framing & HD60

Base preservada: R49 final verificada.

## KOMBAX Social
- Presentación por orientación real: horizontal 16:9, vertical 9:16 y cuadrado 1:1.
- El contenido abre en visor fullscreen mostrando el original completo (`contain`).
- Encuadre editable en foto y vídeo: Mostrar completo / Rellenar marco + control de foco.
- Corregida la colisión CSS móvil que imponía `cover !important` y podía recortar caras/cabezas.
- Vídeo ampliado a máximo 60 s (tolerancia backend 60,2 s), hasta 100 MB y envolvente HD 1080p independiente de orientación.
- MP4 es el formato recomendado; se preserva compatibilidad de lectura/contrato con WEBM/MOV existente.
- Álbum Social directo, álbum de Club y álbum de Perfil Directo quedan alineados al contrato HD60.

## KOMBAX Events
- Contrato UX alineado a vídeo de hasta 60 s / HD 1080p / 100 MB; la base Events ya soportaba el límite temporal y resolución, por lo que no se duplicó arquitectura.
- Se conserva el tratamiento premium R48/R49, Main Event, Co-Main Event, cartelera completa y visor multimedia.

## Backend R50
Migraciones locales canónicas:
- `241_kombax_social_hd60_media_r50.sql`
- `242_kombax_social_identity_album_hd60_r50.sql`
- `243_kombax_social_hd_guard_search_path_r50.sql`
- `244_kombax_social_hd_guard_orientation_r50.sql`

La primera tentativa incremental de compatibilidad del álbum de identidad falló por sintaxis dentro de `nullif`; la transacción se revirtió completamente. La versión corregida se aplicó después sin DDL parcial.

El helper final `app_kombax_social_video_hd_guard_v241` usa `search_path=public`, no permite ejecución directa a `anon`/`authenticated` y valida orientación mediante `greatest(width,height)<=1920` y `least(width,height)<=1080`.

## Nomenclatura
La interfaz, documentación R50 y migraciones R50 usan exclusivamente **KOMBAX Social** y **KOMBAX Events**.

## Despliegue
No se ha realizado deploy de frontend a Netlify ni push a GitHub.
