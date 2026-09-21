# Netlify · KOMBAX build 20025

## Preparación incluida

`netlify.toml` ejecuta `npm run build` y publica `dist`. JavaScript, CSS, configuración y service worker se sirven sin caché persistente; los assets pueden usar caché de medios. La navegación SPA redirige a `index.html`.

## Puertas previas

No desplegar hasta que:

- Supabase 037–042 esté aplicado y verificado;
- las pruebas RLS/E2E reales estén cerradas;
- se decida si los flags `demoDirectory` y `showcaseDemo` se mantienen para una presentación o se desactivan para producción;
- `npm test` y `node scripts/build.mjs` pasen sobre el mismo commit;
- `BUILD_MANIFEST_SHA256.txt` corresponda al paquete.

## Despliegue

1. Usar el mismo commit/ZIP que superó validación, sin editar `dist` manualmente.
2. Ejecutar localmente `npm run build`.
3. Publicar con Netlify desde el repositorio autorizado o arrastrar exclusivamente `dist` para una vista controlada.
4. No subir JKS, `keystore.properties`, `google-services.json`, `.env`, APK ni AAB.
5. Tras desplegar, comprobar carga limpia, Ctrl+F5, PWA, login, selector de club, Comunidad del Club, KOMBAX Social, Showcase y cierre de sesión.
6. Confirmar que `config.js` señala el proyecto Supabase autorizado y que el contrato 041 declara `app_kombax_social_mutate_v041`.

Netlify no sustituye la validación Android ni certifica el backend.
