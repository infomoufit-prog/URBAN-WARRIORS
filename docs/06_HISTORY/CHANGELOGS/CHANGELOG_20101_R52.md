# KOMBAX 20.101 R52 · SOCIAL VIDEO COVER INHERITANCE

Base inmutable: R51 `VIDEO_COVERS_ALBUM_FRAMING`.

## Corrección
- Corrige el flujo Club → Álbum → KOMBAX Social y Perfil Directo → Álbum → KOMBAX Social.
- La portada automática/seleccionada y el encuadre ya no se pierden al crear la referencia Social del mismo asset.
- Añade herencia backend mediante trigger para clientes actuales y futuros.
- Añade fallback frontend defensivo para entornos que aún no tengan aplicada la migración R52.
- Backfill de referencias Social existentes con `media_presentation={}` cuando comparten exactamente el mismo asset con un álbum Club/Perfil Directo que sí contiene presentación.

## Caso real reproducido
El vídeo de Urban Warriors publicado el 05/09/2026 16:53 (37,87 s) tenía portada automática correcta a 9,47 s en `kombax_club_media`, mientras la referencia `kombax_social_media` estaba vacía. R52 hereda esa presentación y el feed vuelve a obtener `media_cover_url`.

## Preservación
- R51 permanece congelada y no se modifica.
- Sin despliegue Netlify.
- Sin push GitHub.
- Sin publicación Google Play.
