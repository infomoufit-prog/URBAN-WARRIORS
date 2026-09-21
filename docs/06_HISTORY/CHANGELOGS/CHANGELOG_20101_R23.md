# CHANGELOG · KOMBAX 20.101 R23

## Corregido
- Los 10 retratos demo del evento Urban Warriors pasan a resolver primero al asset empaquetado de la build en todos los runtimes.
- Una URL demo remota obsoleta o no disponible ya no puede romper Main Event, Fight Card ni fichas de participantes Urban.
- `scripts/serve.mjs` entrega `.webp` como `image/webp` y `.svg` como `image/svg+xml` para validación local por CMD/Chrome.
- Reconocimiento explícito de `127.0.0.1` y `appassets.androidplatform.net` en el helper de runtime.
- Cache bust actualizado a `20101r23` / `media-r23`.

## Preservado
- URLs HTTPS reales de eventos no demo siguen usando el resolver genérico existente.
- Fight Card R22, Main Event/Co-Main, paginación keyset, álbum 30 fotos y asset reuse permanecen intactos.
- No hay migración R23 ni cambios de datos Supabase.
- Sin cambios en Finanzas, Auth, Showcase, Social, package Android, versionCode o firma.
