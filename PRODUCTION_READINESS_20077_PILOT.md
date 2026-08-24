# KOMBAX RC13 build 20077 · Production Readiness · Piloto real

Fecha de cierre técnico: 24/08/2026  
Fuente de verdad: `KOMBAX_Urban_Warriors_RC13_build_20077_DATA_LIFECYCLE_ANALYTICS_OWNER_ACCESS.zip`  
Objetivo: piloto controlado con Urban Warriors + segundo club.  
**No se ha realizado push a GitHub ni despliegue a Netlify.**

# Veredicto

## GO PILOTO CON CONDICIONES

No se ha encontrado un P0 de seguridad o integridad en el candidato local ni en la muestra viva revisada de Supabase. El candidato puede avanzar a la secuencia de publicación/piloto **cuando se cierren las condiciones P1 operativas indicadas en este informe**. No debe considerarse todavía `GO PILOTO` sin condiciones porque el backup+restore real y varios E2E humanos/hosted aún no están certificados.

---

# 1. Legal y Child Safety

**Estado: PASS** para los documentos globales y mecanismos técnicos del piloto.  
**Estado adicional: REQUIERE USUARIO** para completar el DPA del segundo club con su razón social/NIF/CIF/representante.

Implementado y verificado:

- responsable: BRYAN RIVERA GREY, NIF 42303973G;
- domicilio legal facilitado incorporado;
- canales `soporte@kombax.es`, `privacidad@kombax.es`, `childsafety@kombax.es`, `seguridad@kombax.es` y `auth@kombax.es` documentados;
- política de privacidad, términos, estándar Child Safety, runbook Child Safety, registro de tratamientos y gate legal actualizados;
- distinción RGPD entre tratamiento privado por cuenta del club y tratamientos globales propios de KOMBAX;
- retenciones 20077 documentadas;
- mecanismo de denuncia/bloqueo, moderación y protecciones de menores ya presentes;
- tolerancia cero frente a CSAE/CSAM, grooming, sextorsión y explotación sexual infantil documentada;
- punto humano de Child Safety identificado;
- `npm run release:legal-gate` = PASS;
- regresiones legales 20071/20072 = PASS, sin marcadores `[[KOMBAX_*]]` pendientes en superficies de release.

DPD/DPO: no designado en el piloto actual; la conclusión debe revisarse si aumenta sustancialmente la escala, el seguimiento sistemático o el tratamiento a gran escala de categorías especiales.

# 2. Backup / Restore

**Estado: PASS para backup real + verificación de integridad.**  
**Estado adicional: REQUIERE CONFIRMACIÓN DE COSTE/ORGANIZACIÓN para restore aislado.**

Evidencia real viva en Supabase:

- snapshot `20077-2026-08-24T13-38-02-170Z`;
- estado `verified`;
- 3 artefactos de base de datos;
- 47 objetos Storage;
- 26.269.021 bytes verificados;
- SHA-256 del manifiesto `533110e29d0ccb179510fb467f61cd63d8ecee52dda1af6b09760d9b2b4c2da3`;
- `verification_failures = 0`;
- bucket privado `kombax-backups`;
- datos transitorios de Auth (sessions, refresh tokens, OTP/flow state) excluidos deliberadamente del backup para evitar restaurar credenciales caducadas/activas.

Hardening adicional aplicado:

- `kombax_backup_export_tokens_v141` con RLS y sin acceso `anon/authenticated`;
- `kombax_backup_runs_v142` con RLS y sin acceso `anon/authenticated`;
- funciones `backup-export-20077` y `backup-verify-20077`;
- el capability token ya no viaja en query string: usa `x-kombax-backup-token`;
- test `test-kombax-20077-backup-export-gateway.mjs` incorporado a la suite permanente.

Pendiente para cerrar DR como PASS completo: restaurar este backup en un branch/proyecto Supabase aislado y comparar tablas, conteos y Storage. La creación del branch exige la confirmación explícita de organización y coste requerida por Supabase.

# 3. Email / Auth E2E

**Estado: PASS para entrega real y plantillas críticas.**  
**Estado adicional: PENDIENTE Site URL y E2E de variantes autenticadas.**

Evidencia real obtenida el 24/08/2026:

- usuario confirmó recepción humana de los correos de prueba;
- registro real = HTTP 200 + correo recibido;
- asunto alojado actual: `Confirma tu cuenta de KOMBAX`;
- contenido de confirmación en español y branding KOMBAX;
- recuperación real = HTTP 200 + correo recibido;
- asunto alojado actual: `Restablece tu contraseña de KOMBAX`;
- remitente `KOMBAX <no-reply@kombax.es>`;
- las 13 plantillas de Supabase Auth han sido configuradas en español por el propietario;
- las plantillas críticas verificadas ya están efectivamente activas;
- rate limit de recuperación respondió 429 al repetir demasiado pronto, comportamiento defensivo esperado.

Pendiente:

1. `redirect_to` de los emails alojados sigue apuntando a `https://urban01.netlify.app/`; cambiar Site URL/Redirect URLs a `https://kombax.es` coordinado con el deploy real;
2. clic humano de confirmación para completar el flujo de alta de extremo a extremo;
3. E2E autenticado de invitación EQP y ALU, que pasa por funciones propias de KOMBAX;
4. E2E Owner de OTP crítico sin ejecutar una acción destructiva.

No se ha consumido ni publicado ningún OTP/código de recuperación durante esta auditoría.

# 4. Health / Observabilidad

**Estado: PASS** para health, jobs existentes e incidentes cliente.  
**Estado adicional: REQUIERE USUARIO / ventana real** para monitor externo y primera ejecución lifecycle.

Vivo en Supabase:

- `health` GET = HTTP 200, función build 20077;
- `urban-warriors-notification-dispatch` = activo, `*/10 * * * *`, ejecuciones recientes `succeeded`;
- `urban-warriors-payment-reminders` = activo, `5 * * * *`, ejecuciones recientes `succeeded`;
- `kombax_client_incidents_v117` = 0 total / 0 últimas 24 h / 0 últimos 7 días;
- `kombax-data-lifecycle-daily-v133` = activo, `20 2 * * *`, todavía sin primera ejecución programada registrada al cierre de esta auditoría.

El POST 401 observado anteriormente en `invite-email` fue una prueba sin autenticación y confirma rechazo defensivo; no se interpreta como caída.

Pendiente P1 operativo:

- comprobar la primera ejecución programada del lifecycle tras su próxima ventana;
- `KOMBAX Health Watch` ya está activo con comprobación horaria del endpoint health y solo notifica ante fallo/degradación/build distinto de 20077; tras desplegar `kombax.es`, ampliar la vigilancia al dominio web.

# 5. Auth Security

**Estado: PASS para piloto con P1/P2 registrados.**

Comprobado:

- Owner normal: password reciente + sesión privilegiada ligada al `session_id`, 30 min;
- OTP solo para operaciones críticas/destructivas;
- Support Mode temporal y auditado, sin membresías falsas;
- helpers críticos de borrado no accesibles directamente por `anon`/`authenticated`;
- tablas sensibles muestreadas sin grants directos para `anon`/`authenticated`;
- RPC sensibles muestreadas revalidan Owner/moderador/ámbito financiero/OTP antes de mutar.

Advisor actual de Supabase:

- `leaked password protection` desactivado; el proyecto está en Free y la función es Pro+;
- linter nuevo avisa sobre RPC `SECURITY DEFINER`. Las cuatro RPC públicas revisadas solo devuelven datos deliberadamente públicos. Las privilegiadas muestreadas contienen controles internos. No se ha aplicado una revocación/refactor masivo por riesgo de romper el gateway.

Ver auditoría: `SUPABASE_SECURITY_DEFINER_AUDIT_20077.md`.

---

# Regresión final del candidato

| Control | Estado | Evidencia |
|---|---|---|
| Gate legal | PASS | `npm run release:legal-gate` |
| Suite completa | PASS | `npm test` |
| Build web/PWA | PASS | `npm run build` |
| Paridad web/dist/Android | PASS | 73/73/73 archivos, 0 missing, 0 extra, 0 hash diff |
| Escaneo de secretos | PASS | sin JKS/keystore/private key/service-role incrustado |
| `google-services.json` | PASS con nota | configuración cliente Firebase; no contiene private key; está ignorado por git |
| Dominio en código candidato | PASS | sin `urban01.netlify.app` en superficies productivas; `kombax.es` configurado |
| Hosted Auth templates | PASS críticas | registro y recuperación recibidos en español |
| Hosted Auth Site URL | REQUIERE PUBLICACIÓN | aún redirige al Netlify antiguo; cambiar a `kombax.es` coordinado con deploy |
| Android preflight | REQUIERE USUARIO | 4/5; falta firma local segura |
| RLS/multiclub | PASS | regresión PASS + evidencia viva previa de aislamiento bidireccional |
| Owner | PASS | regresión 20077 + funciones vivas inspeccionadas |
| Support Mode | PASS | regresión 20077 + modelo auditado |
| Lifecycle/retention | PASS implementación | primera ejecución cron real todavía pendiente |
| Finanzas | PASS | regresiones + chequeos de ámbito en RPC viva muestreada |
| Social/Showcase | PASS | regresiones; RPC públicas Showcase limitadas a publicado |
| Menores/Child Safety | PASS | consentimientos, no chat privado <18, reporting/moderación, documentos legales |
| Supabase Security Advisor | PASS con P1/P2 | sin bypass P0 demostrado; leaked-password Pro+ y SD gateway documentados |
| Backup real | PASS | snapshot verificado: 3 DB + 47 Storage, 0 fallos, 26.269.021 bytes |
| Restore aislado | REQUIERE CONFIRMACIÓN | branch/proyecto aislado pendiente por confirmación obligatoria de coste/organización |
| Supabase Performance Advisor | PASS para piloto / P2 | INFO de FK sin índice e índices sin uso; optimizar con métricas reales |

# Hallazgos priorizados

## P0 — bloqueantes críticos

**Ninguno demostrado** en el alcance revisado.

## P1 — condiciones para pasar de “con condiciones” a “GO PILOTO”

1. Restore aislado certificado a partir del backup real ya verificado.
2. Cambiar Site URL/redirect a `kombax.es` coordinado con deploy; las plantillas críticas alojadas ya están activas en español.
3. Completar E2E humano: clic de confirmación, EQP/ALU y Owner critical OTP.
4. Completar DPA del segundo club.
5. Ver primera ejecución `kombax-data-lifecycle-daily-v133` como `succeeded`.
6. Generar APK/AAB firmada con keystore local y validar instalación/upgrade.
7. Tras deploy, activar monitor externo de `kombax.es` + health.

## P1/P2 — hardening no bloqueante del piloto cerrado

- leaked-password protection al subir a Supabase Pro;
- certificar CAPTCHA/bot protection antes de registro público amplio;
- formalizar allowlist/auditoría de RPC `SECURITY DEFINER`;
- ajustar rate limits según tráfico real.

## P2 — rendimiento/mantenimiento

- priorizar índices de foreign keys por perfiles de consulta reales;
- no eliminar índices marcados “unused” hasta tener una ventana de tráfico representativa.

# Secuencia autorizable de lanzamiento

Cuando los P1 previos estén cerrados y el propietario autorice expresamente publicación:

1. GitHub privado: commit final del candidato y push autorizado.
2. Netlify: deploy a `kombax.es`.
3. Supabase Auth: Site URL/Redirect URLs + plantillas hosted finales.
4. QA PWA en dominio real.
5. APK/AAB firmada; smoke test Android y actualización.
6. Urban Warriors como club 1.
7. Segundo club con DPA completado y datos mínimos reales.
8. Monitorización reforzada durante los primeros 7 días.

**Hasta autorización expresa, GitHub y Netlify permanecen sin cambios.**

### Actualización 24/08/2026 · backup real

- **Backup export real: PASS.** Snapshot `20077-2026-08-24T13-38-02-170Z`.
- **Integridad: PASS.** 50/50 artefactos verificados por SHA-256, 0 fallos, 26.269.021 bytes.
- **Capability: PASS.** Token efímero por cabecera, revocado al finalizar; secreto temporal eliminado de Vault.
- **Restore aislado: PENDIENTE.** Sigue siendo condición P1 hasta restaurar en un destino independiente de producción.

