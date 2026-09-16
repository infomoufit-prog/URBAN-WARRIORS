# AUDITORÍA SOCIAL FEED R46

## Estado previo confirmado
- Existían like, guardados, comentarios, denunciar y bloquear.
- No existía ocultado personal de una publicación.
- El feed principal era cronológico por fecha/id.
- Las acciones estaban todas expuestas en el footer, generando saturación visual en móvil.

## Implementado
- UX de feed continuo inspirado en patrones sociales generalizados, sin copiar branding externo.
- «Me interesa» usa la reacción persistente existente.
- Ocultado personal RPC-only.
- Ranking inicial explicable y reversible.

## Backend vivo
- Migración `kombax_social_feed_relevance_r46` aplicada al Supabase principal el 2026-09-05.
- La lista de migraciones confirma su presencia.
- La relectura SQL específica de ACL/RLS fue bloqueada por el conector de seguridad; no se declara verificada por esa vía.

## QA
- R46 focal: 15/15 PASS.
- npm test: EXIT 0.
- npm run build: PASS.
- Paridad web/dist/Android: 189/189/189, 0 diferencias.
- Android preflight: consultar evidencia; signing local sigue siendo requisito separado.
