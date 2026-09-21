# KOMBAX RC13 · build 20085 · PREMIUM FINANCE + SOCIAL QA

Fecha de cierre técnico: 2026-08-25

## Objetivo

Cerrar la desincronización detectada entre el frontend 20084 y Supabase, elevar Finanzas Premium al nivel visual/interactivo previsto y mantener el aislamiento estricto de identidad de KOMBAX Social antes de la APK/AAB y del piloto.

## Frontend 20085

- Dashboard Finance Premium activado mediante flags por club.
- Analítica visual v150: evolución mensual SVG, antigüedad/deuda, categorías, grupos y disciplinas.
- KPIs y visualizaciones navegables con drill-down y filtros cruzados.
- Previsión 30 días y porcentaje de morosidad.
- Modo móvil y sincronización determinista web = dist = Android assets.
- Social conserva el aislamiento de workspace 20083 y usa RPC v147.

## Backend Supabase sincronizado

Producción incluye el bloque Finance/Security 143–154 relevante para 20079–20085:

- 143 Finance Premium foundation.
- 144 dashboard/manual charge.
- 145 informes históricos privados.
- 146 Shadow QA financiero.
- 147 aislamiento Social por workspace/identidad.
- 148 gate final Finance pilot.
- 149 Security Go-Live / Owner AAL2.
- 150 analítica visual Finance Premium.
- 151 rollout UI del piloto (solo flags visuales/informes).
- 152 corrección del path de anomalías en readiness.
- 153 compatibilidad real de firma VARIADIC de roles.
- 154 índices de soporte Finance/Security añadidos en 20085.

Edge Functions desplegadas:
- `finance-report` · JWT obligatorio.
- `finance-recurring` · autenticación de cron propia; ejecución real sigue cerrada por gates DB.

## Integridad de datos

Conteos antes y después del bloque de migraciones:
- cuotas: 13 → 13
- pagos: 8 → 8
- recibos: 6 → 6
- contactos Social: 9 → 9
- mensajes privados: 24 → 24

No se generaron cargos reales ni se modificó historial financiero durante la sincronización.

## E2E de lectura · Urban Warriors

Finance v150 devolvió datos reales:
- generado: 603,00 EUR
- cobrado validado: 274,00 EUR
- pendiente: 329,00 EUR
- vencido: 299,00 EUR
- porcentaje cobro: 45,44 %
- alumnos con deuda: 3
- 15 puntos/meses de evolución disponibles
- 5 tramos de aging
- datos por categoría, grupo y disciplina

Social v147:
- actores globales gestionados por la cuenta probada: 2
- actores permitidos en workspace Urban Warriors: 1
- perfil directo excluido: 1
- conversaciones globales: 6
- conversaciones permitidas en workspace: 5
- conversación excluida del workspace: 1
- `private_context_isolated=true`

## Gates de seguridad del piloto

Urban Warriors y QA club:
- finance_v2_enabled = true
- finance_dashboard_v2_enabled = true
- finance_reports_enabled = true
- finance_recurring_enabled = false
- finance_qa_shadow_approved = false
- finance_pilot_live_enabled = false

Plataforma:
- owner_mfa_required = false hasta enrolar/verificar AAL2.
- pilot_security_enabled = false.
- Leaked Password Protection sigue pendiente de activación en Supabase Auth.

Readiness Finance comprobado:
- anomalías bloqueantes = 0
- QA aprobado = false
- pilot_ready = false
- pilot_live = false

Por tanto, la UI Premium queda disponible para QA pero no existe activación automática de cargos recurrentes reales.

## Advisors

Security Advisor: las advertencias RLS sin policy y SECURITY DEFINER conocidas se mantienen clasificadas según el diseño RPC/least-privilege. Las superficies públicas anónimas intencionales siguen limitadas al catálogo/directorio/Showcase. Queda pendiente activar Leaked Password Protection.

Performance Advisor: no aparecen bloqueos; existen INFO históricos sobre FKs sin índice e índices aún no usados. En 20085 se añadieron únicamente índices de soporte para las nuevas tablas Finance/Security para evitar cambios masivos antes del piloto.

## Certificación local

- `npm test`: PASS.
- `npm run release:build`: PASS.
- build determinista: 79 archivos, web = dist = Android.
- Android preflight: 4/5; único PENDIENTE = `android/keystore.properties`, que debe permanecer local en el PC de firma.

## Estado de salida

- BACKEND 20085: SINCRONIZADO EN SUPABASE.
- FRONTEND 20085: LISTO PARA DESPLIEGUE POR GITHUB DESKTOP/NETLIFY.
- APK/AAB 20085: PENDIENTE DE GENERAR Y FIRMAR EN ANDROID STUDIO.
- PILOT SECURITY READY: CERRADO hasta MFA Owner, Leaked Password Protection, restore drill y QA E2E final de los dos clubes.
- RECURRENCIA REAL: CERRADA.
