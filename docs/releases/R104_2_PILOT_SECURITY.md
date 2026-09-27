# KOMBAX R104.2 — parche de seguridad del piloto

Fecha: 27/09/2026. Base: R104.1/20156. Alcance: tres RPC Showcase y documentación de auditoría. El trabajo Owner de escala y las funcionalidades pospiloto no forman parte de este incremento.

## Cambio

- `290_kombax_showcase_listing_visibility_pilot.sql`: los detalles públicos de tipo y estado de stock se limitan a productos y proveedores publicados; el gestor autorizado conserva acceso a sus borradores.
- `291_kombax_showcase_commerce_details_visibility_pilot.sql`: el mismo aislamiento se aplica a precio, stock exacto, variantes y demás datos de Commerce para usuarios autenticados.
- `292_kombax_showcase_compliance_visibility_pilot.sql`: datos de cumplimiento de borradores accesibles solo para gestor autorizado o plataforma; productos publicados mantienen acceso según el contrato existente.
- Se preservan nombres, argumentos, columnas y permisos de las RPC. Las tres migraciones están aplicadas al proyecto Supabase piloto.
- Evidencia y asuntos pendientes: `informes-tecnicos/seguridad/SUPABASE_SECURITY_GATE_2026-09-27.md` y `informes-tecnicos/piloto/KOMBAX_PILOT_2026.md`.

## QA y reversión

Antes del parche se reprodujeron lecturas de datos de borrador mediante transacciones revertidas. Después pasaron las aserciones para producto publicado, borrador del gestor y borrador de otro club en las tres RPC. Todas las mutaciones de estado utilizadas en la prueba se revirtieron. La consulta final confirmó que el producto de muestra seguía publicado.

Rollback técnico, solo si apareciera regresión demostrada: restaurar las definiciones anteriores de las RPC desde una copia verificada de Supabase y repetir la prueba de acceso; esa reversión reabriría la exposición y no se recomienda sin una alternativa segura.

**Release gate: NO-GO.** El propietario decidió aplazar TOTP hasta después del piloto; no se activa AAL2 y se mantiene el riesgo de un solo factor. Siguen abiertos recuperación externa/aislada, readiness y ensayo de cuatro clubes con sesiones reales. Netlify y Google Play permanecen fuera de este parche.
