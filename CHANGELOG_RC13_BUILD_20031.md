# KOMBAX / Urban Warriors RC13 · build 20031

## QA social profile fix
- Corrige las políticas de Storage de KOMBAX Social para la ruta real `usuario/social/perfil/archivo`.
- Consolida avatar y portada pública del perfil Social mediante fuente canónica + trigger de sincronización.
- Corrige referencias PL/pgSQL ambiguas a `id` detectadas en QA.
- El feed, directorio, comentarios, selector de identidad y perfil público resuelven el mismo avatar.
- Al cambiar la foto privada de `Mi perfil`, el usuario puede aceptar explícitamente reutilizarla como foto pública de KOMBAX Social.
- Añade acceso directo `Ver mi perfil público KOMBAX`.
- Autor/avatar de cada publicación muestra la acción `Ver perfil` y es accesible por clic y teclado.
- No hace pública automáticamente ninguna foto privada existente.

Estado: candidato QA local. No desplegar Netlify/GitHub/Android release hasta cerrar E2E.
