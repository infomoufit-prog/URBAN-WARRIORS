# KOMBAX 20.107 R57 · Auditoría previa · KOMBAX Social Information UX

Fecha: 2026-09-06
Base: KOMBAX 20.106 R56 · PROFILE PUBLIC UX FREEZE CANDIDATE
Alcance: frontend/UX de KOMBAX Social. Sin cambios funcionales en feed, moderación, multimedia, privacidad, Events, Showcase ni perfil público.

## Hallazgo

La vista principal de KOMBAX Social renderizaba de forma permanente tres bloques informativos antes del contenido útil:

1. `kx-identity-context`: identidad activa / "ACTUAR COMO".
2. `kx-social-topic-policy`: política temática y explicación extensa de moderación.
3. `kx-social-rules-card`: normas y límites de publicación.

El editor de publicación ya contiene un recordatorio contextual breve (`kx-social-publish-topic-hint`: "Solo contenido de combate"), por lo que mantener además los dos bloques extensos en la portada producía duplicación y retrasaba el acceso al feed.

## Decisión de arquitectura UX

- No eliminar información ni capacidades.
- No alterar las reglas de moderación.
- No alterar la identidad que firma una publicación.
- No alterar el compositor ni el aviso contextual corto.
- No alterar el anuncio de lanzamiento de competidores fundadores.
- Mover identidad activa + normas completas + explicación de moderación a un panel secundario accesible mediante un botón de información compacto en la cabecera de KOMBAX Social.
- Mantener cambio de identidad dentro de dicho panel cuando la cuenta administra más de una identidad.

## No afectados

Verificados por SHA-256 frente a R56:

- `web/js/modules/kombax-events.js`: `2bc0f20a14f84e2d8164d250de1ca03eeba484ebe31fff73a5df0624d3345549`
- `web/js/modules/showcase.js`: `af769c24f454393515da9822077d62159953d263405178a7952edd6b8f0edbae`
- `web/js/modules/public-profile.js`: `8f48e786349b00a5ef59c4d4544c2a2ea94d163cdad6803af3d49ba43ec6b5eb`
- `web/js/core/repositories.js`: `dfd0474ed65336208a66b620f85f842419fee19de54418edf072e9b2e6f3c4c4`

## Riesgos revisados

- Pérdida de selector de identidad: mitigado; permanece en el panel de información y actualiza `activeIdentityId` + `setActiveIdentity()`.
- Pérdida de normas: mitigado; se reutilizan exactamente `socialTopicPolicyNotice()` y `socialRulesCard()` dentro del panel.
- Pérdida de recordatorio en publicación: no se modifica `kx-social-publish-topic-hint`.
- Regresión de multimedia/visibilidad/feed: no se modifica repositorio ni backend Social.
- Regresión de Android/PWA: build sincroniza la misma carpeta `web` a `dist` y `android/app/src/main/assets/www`; paridad SHA obligatoria.

## Dictamen

Cambio apto para una revisión frontend derivada R57. No requiere migración de base de datos. El endpoint `health` se actualiza únicamente como marcador de release build 20107.
