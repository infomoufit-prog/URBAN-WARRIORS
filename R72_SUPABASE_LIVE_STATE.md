# KOMBAX R72 · Estado Supabase live

Proyecto: `poggsobhtutbuagjiydc`  
Build de aplicación: **20123**

## Migraciones R72 aplicadas
- `20260914185428_kombax_r72_01_catalog_foundation`
- `20260914185453_kombax_r72_02_reputation_schema`
- `20260914185518_kombax_r72_03_showcase_capacity`
- `20260914185547_kombax_r72_04_catalog_entitlements`
- `20260914185556_kombax_r72_05_verified_reputation_helpers`
- `20260914185646_kombax_r72_06_showcase_reviews`
- `20260914185719_kombax_r72_07_events_community`
- `20260914185741_kombax_r72_08_safe_delete_storage`
- `20260914185755_kombax_r72_09_reputation_moderation`
- `20260914185813_kombax_r72_10_contracts_policies`
- `20260914190143_kombax_r72_11_reputation_fk_indexes`

El historial live contiene **11 entradas canónicas R72**. Durante la certificación se detectó un segundo juego de entradas de historial con los mismos cambios idempotentes; se eliminaron únicamente esas entradas repetidas de `supabase_migrations.schema_migrations`, conservando el primer juego canónico. No se revirtió ni eliminó funcionalidad/datos R72.

La carpeta `supabase/migrations/` del ZIP usa esas mismas once versiones. La versión monolítica de diseño se conserva solo como referencia en `supabase/reference_migrations/R72_MONOLITHIC_REFERENCE_20123.sql`.

## Verificación SQL posterior
- `showcase_catalog_plus_25`: **25 slots / 30 días / 800 minor = 8 EUR**, renovable y acumulable.
- Servicio comercial `showcase_catalog_plus_25`: activo.
- Tablas privadas `kombax_reputation`: **4** (`product_reviews`, `event_comments`, `event_reviews`, `reputation_reports`).
- RPC con sufijo R72 en `public`: **16**.
- Políticas Storage R72 para multimedia de reputación: **2**.
- Índices R72 presentes: **13**.
- FKs de `kombax_reputation`: **12**, con **0 sin índice de cobertura** tras la migración 11.
- Marketplace QA activo: `marketplace_terms`, `seller_agreement`, `buyer_protection`, `prohibited_products` en `1.2-r72-qa`; revisión jurídica `pending`.
- Events QA activo: `events_ticketing_agreement` en `1.3-r72-qa`; revisión jurídica `pending`.

## Health
- Edge Function `health`: **ACTIVE**.
- Versión Edge Function: **30**.
- Build devuelto/configurado: **20123**.
- `verify_jwt=false` preservado deliberadamente porque el endpoint health ya es público.
- SHA Edge Function: `5d76ed7ebbd4c818828a688deada13a3358c61f5b7b0389b986e5e41f7c180c1`.

## Advisors posteriores
Security Advisor: persisten advertencias históricas/proyecto-wide sobre `SECURITY DEFINER`, tablas RLS internas sin policy directa y protección de contraseñas filtradas desactivada.  
Performance Advisor: **215** FKs globales sin índice, **279** índices sin uso y **1** índice duplicado histórico. Los índices R72 recién creados aparecen sin uso por ausencia de tráfico todavía; las 12 FKs nuevas de reputación sí quedan cubiertas.

## Despliegue
Solo se ha actualizado Supabase, dentro de la autorización existente del proyecto. **No** se ha desplegado Netlify/frontend, **no** se ha hecho push a GitHub y **no** se ha publicado Google Play.
