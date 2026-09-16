# Changelog · KOMBAX R74 / build 20125

## Showcase
- Autoprovisión/revinculación idempotente del Seller Center de club para gestores elegibles.
- Reutilización del proveedor existente por club; protección frente a duplicados.
- Backfill seguro de gestores Dirección/Coordinación válidos.
- `Mi Showcase` deja de caer silenciosamente al catálogo público.
- Corrección de `descriptionTranslation is not defined`.
- Productos, pedidos y Stripe Connect existentes no se alteran.

## Events
- Cardinalidad multiclub: un evento público admite conexiones de varios clubes.
- Autorización individual por el organizador público: `pending/approved/rejected/revoked`.
- Compatible con organizador club, federación u otra entidad/cuenta autorizada.
- Conexión y publicación de participantes quedan separadas.
- Sincronización explícita y referencial de participantes/licencias después de aprobación.
- Centro del Evento incorpora “Conexiones de clubes”.
- `Mis eventos` usa el permiso canónico `eventManage`.

## Seguridad / datos
- RLS y deny-all directo para la tabla de compartición de participantes.
- RPC privadas sin `anon execute`; `search_path` controlado.
- Índices R74 para las nuevas FKs tras advisor de rendimiento.
- Sin cambios en QR, Ticketing o Stripe.

## i18n / release
- Copy R74 en EN/ES/FR/PT/IT/DE/TH/FIL.
- R74 formalizada como build 20125 en Web/PWA/Android/health.
- `web`, `dist` y Android assets sincronizados por build determinista.
- Regresión acumulativa incorporada a `npm test`.
