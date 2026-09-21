# Auditoría · KOMBAX Social R47

## Resultado funcional
R47 separa correctamente relevancia personal, visibilidad y moderación. «Ocultar para mí» deja de formar parte del flujo activo. La preferencia es triestado: +1 «Me interesa», -1 «No me interesa», 0 «Sin preferencia». El valor -1 reduce scoring/afinidad pero no elimina la publicación por una regla de ocultado.

## Control de visibilidad
La audiencia pertenece a la publicación y solo puede cambiarla quien controla la identidad autora. El editor ya existe también para publicaciones creadas: `··· > Visibilidad` lee `app_kombax_social_visibility_config_v237`, precarga clubes/perfiles/tipos y persiste mediante `kombax.social.visibilidad`.

Audiencias soportadas: Todo KOMBAX, Mi red, Solo mi club, federación/clubes afiliados, clubes seleccionados, Todo KOMBAX excepto clubes, perfiles concretos y tipos de perfil.

## Multimedia móvil
La orientación se obtiene de dimensiones reales. En móvil: portrait 4:5, square 1:1 y landscape 16:9. El feed usa `cover`; el visor inmersivo usa `contain` sobre 100dvh para mostrar el original completo. Vídeo incluye expansión a fullscreen.

## Seguridad de audiencia/media
Las tablas internas R47 mantienen RLS y no conceden lectura/escritura directa a `anon` ni `authenticated`. Feed/config/mutación se exponen por RPC a `authenticated` y no a `anon`. Cambiar entre audiencia pública y restringida exige compatibilidad con el bucket correspondiente; no se convierte implícitamente un recurso público en privado.

## Evidencia final local
- R47 28/28 PASS.
- R40 74/74 PASS.
- R44 25/25 PASS.
- R45 6/6 PASS.
- R46 15/15 PASS bajo supersesión R47.
- `npm test`: EXIT 0.
- build: 189 archivos.
- paridad: web=dist=Android 189/189/189, 0 diferencias; SHA agregado `ae0d946823295693356a89330faafe8fd90292b2d6de31c9f32d6fa7c0fb1fd6`.
- secret scan activo: 413 archivos, 0 hallazgos.
- Android preflight: 4/5; firma local pendiente por diseño.

## Evidencia viva
Las migraciones `kombax_social_visibility_core_r47`, `kombax_social_feed_preferences_r47` y `kombax_social_mutation_visibility_r47` están registradas. RPC y RLS/ACL R47 se verificaron con SQL vivo. No se creó una publicación E2E real en producción durante el cierre.

## Estado
Candidata PRE-QA / QA. Automatización y backend R47 quedan coherentes. Continúan pendientes QA manual autenticado en dispositivo y cierre global de advisors/ciberseguridad; por tanto no se declara production-ready ni apta todavía para datos personales reales sin esos gates.
