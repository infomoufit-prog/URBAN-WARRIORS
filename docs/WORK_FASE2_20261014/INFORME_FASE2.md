# KOMBAX — Fase 2: Inscripciones y licencias del club

**Referencia:** ZIP acumulativo R120 FIX22 + Fase 0 + Fase 1. Fecha: 2026-10-14.

**Estado:** Implementación frontend local y pruebas automáticas acotadas completadas; sin desplegar, pendiente de E2E autenticado y de validar con usuarios reales. La conversión administrativa de un registro interno existente a una licencia federativa no se ha implementado: requiere especificación y autorizaciones de ambas entidades.

## 1. Hallazgos reales de backend

- Se confirmó con Supabase que existe `app_kombax_recover_club_signup_intents_r262`, que recupera solicitudes de alta confirmadas que quedaron sin completar. Es mecanismo de recuperación administrativo; NO llamarlo en frontend por cuenta propia.
- `app_kombax_membresia_solicitar_r58` es idempotente por ficha y usuario para solicitudes pendientes; devuelve `already_pending` / `already_linked` según caso.
- `app_kombax_club_link_request_r117` comprueba `already_linked` para participante confirmado, pero solicitudes de otro hijo/tutor pueden ser independientes; no bloquear solicitudes familiares solo por tener rol de tutor.
- `app_kombax_club_federation_context_v200` (envoltorio R263) añade una pseudo-relación de UI con sentinel `00000000-0000-4000-8000-000000000263`, que NO es una federación real.
- `app_kombax_federation_mutate_v200` (envoltorio R263) acepta el sentinel para crear registros de licencia administrativa interna y establece `federation_profile_id=NULL`. Rechaza enviar/revisar/compartir con federación un registro interno; permite registrar documentos privados. Las políticas continúan gestionadas por el backend.
- `kombax_federation_licenses_v200.federation_profile_id` admite NULL. No se necesita crear otra tabla ni una migración redundante.

## 2. Cambios de frontend

### Inscripciones

- La búsqueda de club consulta también membresías activas (no solo fichas pendientes de vinculación), evitando que un participante ya vinculado reciba la misma solicitud.
- Si el usuario ya es participante, se presenta la opción de solicitar un espacio **familiar/tutor** usando su misma cuenta, sin volver a solicitar el rol de participante.
- Si el usuario está vinculado como familiar, puede solicitar rol participante cuando corresponda.
- El flujo de vinculación de ficha previa interpreta `already_pending` y `already_linked` de la RPC, sin afirmar falsamente que se ha enviado otra solicitud.
- La vinculación sigue sujeta a confirmación por el club; la interfaz no auto-autoriza nada.

### Licencias

- Se separa el botón **Registro interno del club** del botón **Licencia federativa**.
- El selector virtual R263 desaparece de la sección **Mis Federaciones** y de formularios federativos reales.
- Si no existe federación real activa, no se permite abrir la creación federativa; sí la de registro interno.
- El registro interno utiliza el sentinel **solo como selector de contrato RPC**, nunca lo representa como entidad federativa.
- Listados e identificación visual distinguen registro interno sin validez federativa de licencia federativa.
- El botón **Enviar a Federación** no se ofrece en registros internos.
- Los registros internos no incluyen controles de compartir documentos.
- Las licencias federativas no comparten archivos por defecto; la casilla requiere selección positiva del usuario.
- Se mantiene la integración con carga de documentos en Storage protegida por backend.

## 3. Arquitectura y archivos

- `web/js/core/internal-club-license.js` nuevo: clasifica registros internos, filtra federaciones reales y da etiquetas adecuadas.
- `web/js/modules/federation-licenses.js`: flujos claramente diferenciados, validaciones y privacidad.
- `web/js/modules/gateway.js`: navegación de inscripción sensible a vínculos existentes.
- `scripts/test-kombax-phase2-inscripciones-licenses.mjs`: 32 pruebas locales.
- `package.json`: integra la batería de Fase 2 al pretest.
- Se han sincronizado por bytes los tres módulos web modificados o nuevos en `dist` y `android/app/src/main/assets/www`.

## 4. Restricciones y trabajo restante

1. Ejecutar pruebas E2E autenticadas con cuenta de tutor, participante y club autorizado, sin datos de prueba que contaminen el piloto.
2. Validar permisos negativos desde API (no solo interfaz), RLS y Storage para documentación interna y federativa.
3. No está diseñado ni implementado un trámite de **conversión de registro interno a licencia federativa oficial**; requiere aprobación expresa de la federación y estrategia de trazabilidad. Se mantiene el registro interno independiente hasta ese hito.
4. Confirmar que R262 recupera un registro iniciado antes de la confirmación de email, también desde otro dispositivo; no se efectuaron pruebas reales.
5. Comprobar aprobación/rechazo de solicitudes del club y evitar reenvíos después de aceptación con perfiles piloto.
6. Compilar la PWA y Android cuando existan las dependencias; no generar APK falsa.
7. Reconciliar los archivos SQL locales con las migraciones aplicadas en Supabase (R262/R263). No se presentan migraciones inventadas.

## 5. Producción

- Supabase: **0 migraciones nuevas**, **0 Edge Functions** modificadas; contratos R262/R263 ya existían.
- GitHub: sin push.
- Netlify: sin deploy.
- Meta: sin operaciones de publicación.
- Versión interna 20178/R118 conservada para no introducir cambios en caché PWA antes de una release coordinada.
