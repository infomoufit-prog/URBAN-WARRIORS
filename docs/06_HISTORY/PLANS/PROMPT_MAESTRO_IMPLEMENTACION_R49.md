# KOMBAX 20.101 R49 · Prompt maestro de implementación

## Base obligatoria
Trabajar exclusivamente sobre KOMBAX 20.101 R48, preservando R48 intacta. No desplegar frontend en Netlify ni hacer push a GitHub sin autorización explícita. Supabase solo se modifica si la separación funcional Social lo requiere y siempre con migración reversible/auditable.

## Objetivo
Cerrar dos frentes sin degradar lo ya estabilizado:
1. KOMBAX Social: separar definitivamente Like público de Me interesa/No me interesa privado, mantener comentarios/compartir, reforzar el orden del feed y comunicar/enforzar la temática exclusiva de artes marciales/deportes de contacto.
2. KOMBAX Events: aplicar el lenguaje premium R48 también a eventos ya existentes, asegurar jerarquía Main/Co-Main/Fight Card con o sin fotos individuales y añadir microinteracción/visor del cartel sin saturación.

## KOMBAX Social · contrato de producto
- ❤️ Me gusta / Like = reacción pública. Se cuenta en `likes_count` y se muestra junto a comentarios.
- 👍 Me interesa / 👎 No me interesa = preferencia privada del usuario para ranking. No se muestra al autor como contador ni revela quién la marcó.
- La preferencia debe ser independiente del Like: marcar interés no crea un Like; marcar desinterés no elimina un Like.
- Publicación ajena: mostrar acciones Me gusta · Interés (selector Me interesa/No me interesa/Sin preferencia) · Comentar · Compartir si la audiencia permite compartir.
- Publicación propia: no mostrar controles de Me interesa/No me interesa ni Like propio; mostrar métricas públicas Likes + comentarios y mantener gestión/visibilidad en menú.
- El feed debe usar likes como señal social pública y preferencias como señal privada de afinidad, con pesos diferenciados.
- El encabezado y el compositor deben dejar claro que KOMBAX Social es una red temática exclusivamente de artes marciales y deportes de contacto.
- Añadir motivo de denuncia/moderación “Contenido fuera de temática” para que el sistema de moderación pueda retirar contenido no afín con trazabilidad. No introducir borrado automático irreversible por una clasificación dudosa.

## KOMBAX Events · contrato de producto
- El render premium debe aplicarse a eventos nuevos y ya creados porque vive en la capa UI.
- Main Event = máxima jerarquía; Co-Main = segunda jerarquía visible; Under Card = resto.
- Cada combate debe conservar una cabecera/bloque visual aunque no haya foto.
- Las fotos individuales son opcionales. Modos soportados:
  1. Sin fotos: fallback premium con nombres, esquina, VS y metadata.
  2. Cartel general/Fight Card poster: póster completo con todos los peleadores, ampliable.
  3. Fotos individuales: composición visual de ambos peleadores.
- El cartel principal y el cartel general de Fight Card pueden convivir con álbum y lista estructurada.
- Añadir microanimación elegante al cartel: hover/focus/touch con zoom suave/respiración y brillo selectivo; respetar `prefers-reduced-motion`.
- En detalle/página pública, tocar el cartel debe permitir una vista inmersiva a pantalla completa sin recorte (`object-fit: contain`).
- No crear backend nuevo si el álbum/media actual ya soporta el cartel general.

## QA mínimo obligatorio
- Tests focales R49 para separación Like/Interest, copy temático, motivo fuera de temática y poster interaction.
- Regresión R47 Social, R48 Events, R44 Events flow, R40 visibility.
- Suite completa `npm test` EXIT 0.
- Build y paridad web/dist/Android.
- Secret scan.
- Android preflight; documentar firma local si sigue 4/5.
- Si hay migración Supabase: aplicar al proyecto principal, verificar función/RLS/ACL y registrar advisors sin ocultar deuda heredada.
- Empaquetar ZIP completo autocontenido sin `.git`, `node_modules`, `keystore.properties` ni secretos.
- Extraer el ZIP final y ejecutar smoke sobre esa extracción.
