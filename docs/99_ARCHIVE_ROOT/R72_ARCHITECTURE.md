# KOMBAX R72 · Arquitectura

## Catálogo ampliable
`provider_showcase_capacity_r72(provider_id)` calcula:
- plan actual
- capacidad base
- bloques activos +25
- capacidad total
- publicados activos
- archivados
- fuera de capacidad
- recomendación contextual de Enterprise

Cada bloque se representa mediante `kombax_commercial.entitlements_r64` con código `SHOWCASE_CATALOG_PLUS_25`, alcance del provider, 30 días y precio 800 minor.

## Ciclo de vida
Estados de producto R72:
- borrador
- publicado
- archivado
- fuera_capacidad
- retirado
- oculto (moderación/compatibilidad)

`archivado` no consume capacidad.
`fuera_capacidad` conserva referencia/reputación y no aparece públicamente.
`retirado` conserva historia cuando el borrado físico no es seguro.

## Reputación Showcase
Esquema privado `kombax_reputation`:
- `product_reviews`
- `reputation_reports`

Compra verificada se deriva del ledger de pedidos entregados del usuario/producto. Vendedor puede responder/reportar, no modificar ni borrar la crítica.

## Comunidad Events
- `event_comments` con parent_id para respuestas.
- `event_reviews` para puntuación/valoración.
- asistencia verificada se deriva de ticket `used` del usuario.
- lectura pública mediante RPC segura; escritura autenticada.

## Media UGC
Las fotos se almacenan en `kombax-public-media` bajo carpetas propiedad del usuario. Los RPC solo reciben URLs públicas generadas por el cliente y validan cantidad/esquema. Vídeo Events se admite como URL de media KOMBAX existente o subida cliente compatible; el piloto limita la comunidad a media controlada y reportable.

## Seguridad
- Nuevas tablas: RLS habilitado + revocación total a public/anon/authenticated.
- RPC de escritura: `SECURITY DEFINER`, `search_path=''`, comprobación `auth.uid()` y ownership.
- RPC públicas de lectura exponen únicamente contenido `active` y datos de perfil mínimos.
- Moderación global es la única que puede ocultar contenido ajeno.
