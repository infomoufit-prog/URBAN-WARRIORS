# KOMBAX — Auditoría técnica de fase 0

Fecha de corte: **2026-10-14**. Entorno: GitHub `infomoufit-prog/URBAN-WARRIORS`, Supabase `poggsobhtutbuagjiydc`, Netlify `urban01`.

## 1. Integridad y procedencia

- ZIP recibido: `KOMBAX_20178_R120_FIX22.zip`.
- Integridad ZIP: `ZipFile.testzip()` sin archivos corruptos; sin entradas ajenas a la raíz ni enlaces simbólicos.
- 5.731 archivos, 371,5 MiB descomprimidos. En el archivo ZIP hay 5.731 entradas; no contiene carpetas independientes como entradas adicionales.
- El árbol GitHub `main` es completo (`truncated=false`) y contiene **exactamente los mismos 5.731 nombres de archivo** que el ZIP, cotejados por hash de los nombres ordenados. Esto **NO** significa que los contenidos sean iguales.
- El árbol `main` de GitHub corresponde al commit `787c809aa8f0615a26bdb9f25afb8f8371602aba`.
- De 16 archivos clave comparados por SHA de blobs Git, 11 difieren entre ZIP y GitHub: `package.json`, `web/config.js`, `web/js/modules/comms-material.js`, `web/css/app.css`, `web/js/ui/personal-navigation.js`, `web/js/modules/federation-licenses.js`, `web/js/modules/managed-profile-hub.js`, `web/js/modules/finance.js`, `web/js/modules/historical-finance.js`, `web/js/core/repositories.js`, `netlify.toml`. Los otros cinco son idénticos; esta comparación no presupone cuál de las dos copias es más reciente.
- El ZIP es **la base principal de continuidad**. GitHub se usa como contraste, sin sustituirlo ni sobrescribir diferencias a ciegas.
- `package.json`, `web/config.js` y Android `build.gradle` mantienen versión interna R118 y build 20178, mientras que el archivo se denomina R120 FIX22. El README FIX22 explica que la versión Android no cambia; no incrementar el build solo para hacer coincidir el nombre del paquete.
- Copias verificadas idénticas entre `web/`, `dist/` y `android/app/src/main/assets/www/` para `config.js`, `index.html`, `js/app.js`, `js/modules/instagram-integration.js`, `js/modules/federation-licenses.js`, `js/modules/comms-material.js`, `js/ui/personal-navigation.js`, `css/app.css` y `service-worker.js`.

## 2. Supabase: divergencia de migraciones

- Proyecto: **ACTIVE_HEALTHY**; PostgreSQL 17 (resultado de consulta de proyecto).
- Live: **509 migraciones** según historial Supabase.
- ZIP: **459 archivos `.sql`** bajo `supabase/migrations/`. No equivalen necesariamente uno a uno a las migraciones aplicadas (nombres y versiones divergentes; existen migraciones en otros directorios).
- Migraciones recientes de producción aplicadas **después de FIX22**: `kombax_signup_intent_recovery_r262` (2026-10-13), `kombax_club_licenses_without_federation_r263` (2026-10-13), `kombax_club_license_legacy_rpc_security_r263` (2026-10-13), `kombax_internal_license_self_view_r263` (2026-10-13).
- Antigüedad y finanzas históricas: `member_seniority_historical_finance_fix20` registrada el 2026-10-07.
- Meta: `kombax_meta_instagram_fix20` y `meta_instagram_fk_indexes_fix20` aplicadas el 2026-10-07.

**Acción obligatoria:** exportar documentalmente las migraciones r262/r263 a la siguiente base acumulativa tras verificar su definición exacta en producción; no ejecutar `db push` masivo. No reejecutar migraciones por similitud de nombre.

## 3. Roles simultáneos y espacios

- Existe `web/js/core/club-session-role.js`, `web/js/core/workspace-access.js`, `web/js/core/permissions.js`, `web/js/core/backend.js` y `web/js/ui/personal-navigation.js`.
- La sesión dispone de `rol`, `roles` y `memberships`, y `has()` evalúa un conjunto de roles. Sin embargo, el acceso a un club se presenta como un único destino en `accountWorkspaceTargets`, y el espacio activo no separa de forma explícita **participante / tutor / monitor**.
- En `clubSessionRole`, cuando existe coordinación se devuelve `roles:['coordinacion']`, por lo que se deben revisar los efectos sobre el resto de roles autorizados: **riesgo a validar** antes de modificar permisos.
- La BD incorpora `miembros_club` con roles alumno, familia, monitor, dirección, secretaría, economía y comunicación. También existe `tutores_socios`, y `grupos.monitor_principal_id` además de `grupos.monitor_nombre`.
- Recomendación: primero definir un contrato de contexto múltiple, después adaptar las rutas, luego testear RBAC y RLS. No crear otra identidad principal.

## 4. Inscripciones y licencias

- El código existente dispone de altas y vinculaciones, y Supabase tiene la recuperación de intención de inscripción r262.
- Supabase admite ya licencias internas sin federación con estado diferenciado (r263), pero el formulario `web/js/modules/federation-licenses.js` sigue planteando una selección genérica de Federación. Los registros internos se inyectan en un contexto que originalmente gestionaba federaciones.
- **Riesgo funcional:** la acción de documentación `Compartir ahora con esta Federación` aparece con valor predeterminado `true` en la interfaz. Para las licencias internas debe ser `false` y deshabilitarse cuando no hay federación real; debe comprobarse cómo funciona la RPC de documentos.
- No se han probado altas reales ni la interfaz móvil autenticada durante esta fase.

## 5. Finanzas e historial

- Existe RPC `app_kombax_historical_finance_fix20` y frontend `modules/historical-finance.js` para registrar cargos pendientes o pagos históricos; `repos.finance.historical` está conectado.
- Existen tablas `cuotas`, `pagos`, `recibos_cuota`, `kombax_historical_finance_requests_fix20`, además de las estructuras financieras premium.
- Se localizó `repos.receipts.annulReceipt` (anulación de recibos), que no equivale necesariamente a rectificar o compensar una cuota contabilizada. Se requiere una auditoría contable separada, con saldo, auditoría, idempotencia, accesos y relaciones Stripe/SEPA.
- La fecha `socios.fecha_alta` existe. Antes de crear un nuevo concepto de antigüedad hay que comparar la lógica de la migración FIX20 y las fechas administrativas utilizadas.

## 6. Navegación y catálogo

- Existe experiencia reutilizable de sidebar personal en `ui/personal-navigation.js` y hub compartido `modules/managed-profile-hub.js`. Los módulos `competitor-hub.js` y `federation-hub.js` delegan en el hub común.
- Para Material, `web/css/app.css` fija `.product-media{height:150px}` y la parrilla móvil `.material-grid` pasa a una columna para menos de 620 px. Posteriormente se aplica `object-fit:contain`, que conserva la imagen pero no convierte el marco a 1:1.
- Showcase ya dispone de diseño cuadrado en móvil. Se debe extraer un patrón común: grande 1:1 / cuadrícula compacta / lista, con selector manual y preferencia persistente, y comportamiento predeterminado adaptado a tamaño del catálogo.

## 7. Meta e Instagram

- Las cuatro Edge Functions `meta-instagram`, `meta-instagram-callback`, `meta-instagram-deauthorize`, `meta-instagram-data-deletion` están **ACTIVE** en Supabase, versión 3 según listado.
- El ZIP contiene `supabase/functions/_shared/meta-instagram-runtime.js`, `meta-instagram-core.js` y los puntos de entrada de cada función.
- Existen seis tablas en el esquema `kombax_meta`: `audit`, `connections`, `credentials`, `deletions`, `flows`, `publications`.
- **Cuentas conectadas en producción: 0** al momento de la consulta. Por tanto no se ha verificado aquí el OAuth real ni la publicación externa.
- Frontend `web/js/modules/instagram-integration.js` dispone de flujos de conexión, estado, revocación y publicación de imagen de Social; aún falta demostrar desde UI la integración de Events y Showcase y los formatos permitidos por Meta.
- Las pruebas automatizadas de Meta son **simulaciones** con proveedor externo mock, no publicación real.

## 8. Netlify y límites operativos

- Proyecto `urban01` vinculado a `kombax.es`, último deploy publicado id `6ac6bb37234f6c000804784b`, estado `ready`, commit `787c809` del 2026-10-07.
- No se ha desplegado nada ni se han modificado variables o configuraciones.

## 9. Riesgos prioritarios

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Reemplazar FIX22 por `main` | Alto | Congelar ZIP como línea base, comparar cambios por archivo antes de integrar |
| RLS/RBAC de roles simultáneos | Alto | Contexto separado, pruebas negativas y validación servidor |
| Aplicar SQL antiguo sobre r262/r263 | Alto | Reconciliar historial aplicado y SQL realmente vigente |
| Borrado financiero destructivo | Crítico | Anulación y asientos compensatorios; auditoría y consentimiento específico |
| Licencia interna tratada como federativa | Alto | Diferenciación UI, prohibir compartir/submit internos |
| Instagram sin conexión real | Medio/alto | OAuth manual de prueba con identidad autorizada, no publicar sin consentimiento |
| Cambios de CSS en varias superficies | Medio | Tests responsivos y snapshot de Material/Showcase/Android |

## 10. Conclusión de fase 0

**Base auditada, apta para comenzar desarrollo progresivo, NO certificada para despliegue nuevo**. La implementación de la fase 1 todavía no se ha realizado en este hito. Todas las operaciones sobre servicios remotos durante esta fase fueron de solo lectura.
