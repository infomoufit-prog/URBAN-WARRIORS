# CHANGELOG · KOMBAX RC13 build 20.093 · Events Social & Viral

## KOMBAX Eventos
- Landing pública por deep-link `?event=<slug>` y `?fight=<id>` antes del login.
- Engagement personal: `Me interesa` / `Asistiré` + preferencia de notificaciones.
- Puente Social por referencia `publicación -> evento/combate/resultado` sin duplicar datos.
- Feed Social hidrata tarjetas de Eventos manteniendo Social como sistema de publicación/moderación.
- Compartir fuera de KOMBAX con imagen + URL de retorno.
- QR KOMBAX local y escaneable.

## KOMBAX Visual Engine
- Motor Canvas local, sin API de generación ni API key.
- Evento / Fight Card / Resultado.
- Formato post 1080×1080 y Story 1080×1920.
- Templates SVG locales: evento, pelea y resultado en square/story.
- Placeholder local de peleador y fallback Android/WebView.
- Motion visual accesible y `prefers-reduced-motion`.

## Supabase
- 159, 160 y 161 reconciliadas y aplicadas al backend real.
- Corregida incompatibilidad PostgreSQL real de la migración 160 (`ORDER BY` de alias de salida dentro de función SQL).
- 162 aplicada: engagement, deep-link por slug y bridge Social.
- 163 aplicada: 12 índices FK de hardening de Eventos.
- RLS activo y DML directo revocado en las seis tablas de KOMBAX Eventos.
- RPC públicas limitadas a lectura pública visible; mutadores requieren usuario autenticado.

## Release
- Android versionCode 20093.
- Runtime/web/service worker build 20093.
- Edge Function `health` productiva actualizada a versión 13 / build 20093.
