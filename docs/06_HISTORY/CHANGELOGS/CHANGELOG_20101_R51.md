# CHANGELOG — KOMBAX 20.101 R51

## KOMBAX Social
- Portada automática para vídeo preparado.
- Selector de fotograma concreto como portada.
- Opción de subir imagen propia como portada.
- `poster` de vídeo separado del asset MP4.
- Álbum de miembro/perfil, Club y perfiles directos con `Completo / Equilibrado / Rellenar` para fotos y vídeos.
- Eliminación de un vídeo limpia también su portada separada cuando corresponde.
- UX activa mantiene límite R50 de 60 s.

## KOMBAX Events
- Vídeos del álbum usan portada configurable.
- Acción `Elegir portada` para vídeo almacenado.
- Acción `Ajustar álbum` para foto y vídeo.
- Portada resuelta mediante variante `cover` de `event-media-url`.
- Compatibilidad con media histórica sin portada: el vídeo sigue funcionando.

## Persistencia
- `media_presentation` conserva `fit=balanced`, foco, zoom y metadatos de portada.
- Los metadatos de portada restringida mantienen las reglas de visibilidad existentes.
- No se altera el archivo original.
