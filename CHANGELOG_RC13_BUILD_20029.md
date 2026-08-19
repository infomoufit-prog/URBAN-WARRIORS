# CHANGELOG · KOMBAX RC13 build 20029

## Social
- Nuevo compositor rápido de texto visible en el feed.
- Publicación de texto como identidad activa.
- Conservada subida directa de foto/vídeo y selección desde álbum.
- Scroll progresivo/infinite feed mediante `IntersectionObserver`.
- Botón `Cargar más` conservado como fallback.

## Comunidad / Club
- Comunidad del Club marcada explícitamente como interna.
- Enlace directo a KOMBAX Social público.
- Hub del Club separa Comunidad interna de actividad pública KOMBAX.

## Showcase
- Subida directa desde dispositivo de imagen principal + 3 imágenes de galería.
- Storage `kombax-public-media` segmentado para Showcase.
- 054 incorpora políticas de insert/delete protegidas por autorización de gestión.
- Verify y rollback 054 actualizados.

## Visual
- Rojo KOMBAX evolucionado a rojo sangre intenso `#c9001b`.
- Rojo profundo `#65000d` y acento `#ff1235`.
- Microanimaciones de feed/Showcase y feedback de interacción.

## Build
- Web/cache/Android: 20029.
- `applicationId`: `com.urbanwarriors.app` sin cambios.
- `npm test`: PASS.
- `npm run build`: PASS.
- 70 archivos sincronizados: web = dist = Android.
