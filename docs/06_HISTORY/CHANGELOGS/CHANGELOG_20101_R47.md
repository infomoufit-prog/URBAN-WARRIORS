# Changelog · KOMBAX 20.101 R47

- Retirado «Ocultar para mí» del flujo activo.
- Añadida preferencia reversible «Me interesa / No me interesa / Sin preferencia» como señal algorítmica, sin ocultación automática del post.
- Ranking v237 utiliza señales positivas/negativas y afinidad, con compatibilidad de likes históricos.
- Visibilidad de Social ampliada a perfiles concretos y tipos de perfil, preservando matriz R40 de clubes/federaciones/exclusiones.
- Publicaciones propias: `··· > Visibilidad` permite editar la audiencia después de publicar y precarga selecciones existentes.
- Seguridad multimedia: bloqueo de transición entre audiencia pública/restringida cuando el bucket no es compatible.
- Media móvil: portrait 4:5, square 1:1, landscape 16:9; detección por dimensiones reales.
- Visor inmersivo para imágenes y expansión fullscreen para vídeo, con `contain` para mostrar original completo.
- Backend R47 consolidado en migraciones 237/238/239 y verificado en Supabase principal.
- Test focal ampliado a 28 comprobaciones incluyendo carga/persistencia del editor de visibilidad de publicaciones existentes.
