# CHANGELOG · KOMBAX 20.101 R44

## Combat Events · estabilización estructural

- `openEvent(id)` deja de depender de que el evento exista en la caché de discovery. Recupera el detalle por ID y muestra error explícito si ya no es accesible.
- Se añade secuencia de apertura para descartar respuestas antiguas cuando el usuario pulsa distintos eventos rápidamente.
- Se añade invalidación central `invalidateEventDetail()` y se aplica tras cambios de evento, Fight Card, resultados, participantes, media, framing, visibilidad y partners.
- Guardar/editar ya no espera a recargar toda la cartelera antes de continuar el flujo. La discovery se actualiza en paralelo y el evento se abre por ID con refresh forzado.
- El editor recupera `sujeto_tipo/sujeto_id` desde el contexto organizador activo cuando el select `Organiza como` está disabled y no aparece en `FormData`.
- Para Club se prioriza el contexto cuyo `sujeto_id` coincide con el workspace `state.session.club_id`.
- El menú `Gestionar evento` escucha `kx:modal-before-close` y elimina listeners globales y estado de body al cerrar/reemplazar el modal.
- Los carteles/banners demo con rutas locales ya no se colocan en `input[type=url]`; al guardar se conservan si el usuario no los reemplaza.
- El gestor del álbum deja de mezclar media local sintética de los demos con media persistida. Las imágenes demo siguen disponibles en la presentación pública, pero la administración y cuota operan sobre registros reales.
- Cache bust web/PWA elevado a R44 para impedir que dispositivos conserven el módulo Events anterior.

## Backend vivo auditado
Los eventos actuales Urban Warriors presentan estructura consistente: organizador principal único, Fight Cards sin participantes huérfanos y media sin referencias rotas. No se introduce DDL R44.
