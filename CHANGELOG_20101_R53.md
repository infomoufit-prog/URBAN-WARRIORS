# Changelog · KOMBAX 20.101 R53

## Mi red
- Añadida conexión privada universal `conexion_kombax` para perfiles públicos activos/visibles.
- Solicitud con identidad origen propia, aceptación requerida y deduplicación recíproca.
- CTA “Añadir a mi red” integrado en ficha pública y reutilizado desde búsqueda.
- Vínculos profesionales conservados como semántica separada.

## Perfil público universal
- Estructura común para todos los tipos de perfil público.
- Álbum con filtros Todo/Fotos/Vídeos.
- Últimas 5 publicaciones visibles para el espectador.
- Showcase propio del perfil con 4 fichas iniciales, expansión y estado vacío.

## KOMBAX Events
- Bloqueo seguro si no puede leerse la visibilidad actual.
- Bloqueo seguro si no carga el directorio requerido.
- Feedback visible ante fallo/ausencia de detalle en edición.

## Multimedia
- Conservadas las correcciones R52/R52.2 de herencia y render de portadas de vídeo en KOMBAX Social.

## Build
- Web/PWA/Android build 20103.
- Android versionName `2.0.0-rc.13-r53-pilot`.
- 191 Web = 191 Dist = 191 Android; 0 diferencias SHA.
- R53 21/21 PASS; suite completa EXIT 0.

## Backend
- Aplicada migración `kombax_network_public_profiles_r53`.
- Health Edge Function actualizada a build 20103.
