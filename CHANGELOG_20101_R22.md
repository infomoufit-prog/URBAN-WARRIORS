# KOMBAX 20.101 R22 · Performance, Scale, Fight Card Hierarchy & Media Quotas

Base: KOMBAX 20.101 R21 · Global Media Framing.

## Objetivo
Corregir degradación percibida de navegación y flashes negros en Events, preparar el discovery para crecimiento a miles de clubes/decenas de miles de usuarios y mejorar la jerarquía promocional de la Fight Card, manteniendo R21 y los flujos existentes.

## Cambios de rendimiento
- Primer lote de Events acotado a 24 elementos.
- Eliminada la auto-instalación/reparación de demos del camino normal de navegación.
- Caché temporal de detalle para evitar recargas redundantes al volver a una ficha.
- Hidratación multimedia del álbum por proximidad al viewport mediante `IntersectionObserver`.
- Placeholder estable/no negro durante resolución/carga de media.
- Bundle de detalle para reducir round-trips HTTP.
- Debounce de búsqueda y rechazo de respuestas asíncronas obsoletas.
- Paginación keyset/cursor real mediante `app_kombax_eventos_publicos_page_v191`.
- Filtros query/tipo/estado/fase ejecutados en servidor.
- Límite de página hard-bounded a 48; valor normal 24.
- Índice de discovery R22 añadido para la ruta de consulta de Events.

## Fight Card
- Main Event renderizado antes de la cartelera secundaria.
- Main Event con composición visual mayor y más promocional.
- Soporte explícito de Co-Main Event / combate coestelar.
- Undercard visualmente más compacta.
- Hasta 30 combates por evento.

## Media / álbum
- Álbum oficial: hasta 30 fotografías lógicas independientes.
- Los vídeos mantienen límite separado de 5.
- Cartel, banner y fotos de participantes no consumen cuota del álbum mientras no se añadan al álbum.
- Acción para reutilizar cartel, banner o foto de participante en el álbum sin duplicar el binario en Storage.
- Nuevo tipo lógico `foto_referencia` con `source_kind` / `source_id` y unicidad de referencia activa.
- Al añadir una referencia al álbum sí consume una de las 30 posiciones lógicas del álbum.

## Backend R22 aplicado
- `189_kombax_events_performance_scale_fightcard_media_20101_r22.sql`
- `190_kombax_events_bundle_roles_20101_r22.sql`
- `191_kombax_events_keyset_asset_reuse_20101_r22.sql`

Migraciones confirmadas en el proyecto Supabase principal.

## Compatibilidad
- R19 Showcase Urban Warriors preservado.
- R20 seminario Urban Warriors y sus publicaciones internas preservados.
- R21 Global Media Framing preservado.
- No se modificó package Android ni versionCode.
- No se desplegó Netlify y no se hizo push a GitHub.
