# KOMBAX RC13 build 20.090 · Fase 1 · Plan previo de implementación

## Objetivo
Crear la fundación independiente de **KOMBAX Eventos** sin convertir ni exponer los eventos internos de `Mi Club > Eventos`.

## Orden previo a código
1. Congelar 20.089 como fuente de verdad.
2. Auditar `eventos_competicion`, `evento_participantes`, `evento_combates`, router, permisos y QA existente.
3. Mantener el dominio interno sin cambios funcionales.
4. Crear namespace, repositorio, feature flag y navegación global independientes para KOMBAX Eventos.
5. Añadir un modelo Supabase aditivo de eventos públicos con lectura segura por RPC y sin copiar registros internos.
6. Crear identidad visual motion-first con `prefers-reduced-motion`.
7. Incorporar plantillas SVG locales/offline para carteles y Fight Card base, sin API key.
8. Ejecutar regresión completa y build determinista web=dist=Android.

## Fuera de alcance de Fase 1
Organizadores múltiples, patrocinadores, creación pública, inscripciones, Fight Cards con datos reales, Social sharing, QR/deep links, live, vídeos y highlights. Se incorporan en fases 2–5.

## Gate de seguridad
`eventos_competicion` nunca será origen automático de `kombax_eventos_publicos`. La lectura pública no consulta ninguna tabla de eventos internos.
