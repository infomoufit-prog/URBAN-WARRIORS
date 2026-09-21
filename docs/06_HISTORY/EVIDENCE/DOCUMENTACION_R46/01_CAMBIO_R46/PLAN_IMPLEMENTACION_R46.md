# PLAN IMPLEMENTACIÓN R46 · KOMBAX SOCIAL FEED RELEVANCE

## Alcance
- Ajustar la experiencia móvil del feed KOMBAX Social a un patrón de navegación social continuo: cabecera compacta, multimedia protagonista, acciones principales simples y comentarios inmediatamente accesibles.
- Renombrar la reacción primaria existente (like) a «Me interesa», conservando compatibilidad de datos.
- Añadir ocultado personal por publicación, distinto de denunciar/bloquear/moderar.
- Introducir ranking inicial explicable de relevancia basado en señales de interés, guardados, comentarios, afinidad con autores y recencia, excluyendo contenido ocultado por el usuario.
- Mantener visibilidad/audiencias R40, protección de menores, moderación y permisos existentes.

## Riesgos
- Romper paginación del feed al pasar de orden cronológico a relevancia.
- Confundir ocultado personal con moderación global.
- Sobrecargar consultas de feed con scoring.
- Regresiones en comentarios, guardados, likes o enlaces Events.

## Migraciones / archivos
- Nueva migración 236: tabla RPC-only de ocultados personales + índices; RPC de feed relevancia v236; extensión segura del gateway social v123 para hide/unhide.
- `web/js/core/repositories.js`: feed v236 con fallback y acción hide.
- `web/js/modules/kombax-social.js`: UX feed, menú por post, «Me interesa», ocultar y cursor de relevancia.
- `web/css/app.css`: feed móvil edge-to-edge y acciones/comentarios estilo social continuo sin copiar branding externo.
- Test focal R46.

## QA
- Test focal R46.
- Regresión R40/R44/R45 y suite completa.
- Build y paridad web/dist/Android.
- Verificación SQL fuente y backend vivo si se aplica migración.

## Criterios de cierre
- «Me interesa» persiste y conserva contador histórico.
- Ocultar elimina solo para el usuario actual y no altera el post global.
- Feed v236 excluye ocultados y pagina por score+fecha+id sin duplicados.
- Comentarios y multimedia siguen operativos.
- Suite y build sin regresiones.
