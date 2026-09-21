# SUPABASE VIVO · KOMBAX 20.101 R50

Proyecto: `poggsobhtutbuagjiydc`.

## Migraciones R50 registradas en vivo
- `20260905112101 kombax_social_hd_video_60s_r50`
- `20260905112615 kombax_social_hd_video_60s_routes_constraints_r50`
- `20260905112629 kombax_social_hd_video_60s_profile_rpc_r50`
- `20260905112802 kombax_social_identity_album_hd60_r50`
- `20260905113343 kombax_social_hd_guard_search_path_r50`
- `20260905113555 kombax_social_hd_guard_orientation_r50`

## Contrato final
- KOMBAX Social: vídeo hasta 60 s en UX, tolerancia backend ~60,2 s, hasta 100 MB y envolvente HD 1080p independiente de orientación.
- Rutas de publicación directa, álbum de Club y álbum de Perfil Directo alineadas al mismo contrato.
- El guard `app_kombax_social_video_hd_guard_v241` usa `search_path=public`.
- El guard no expone EXECUTE directo a `anon` ni `authenticated`.
- La resolución admite horizontal 1920×1080 y vertical 1080×1920 mediante validación independiente de orientación.
- KOMBAX Events conserva su backend existente de vídeo de hasta ~60 s / 1080p; R50 no crea arquitectura Events duplicada.

## Advisors
Performance Advisor se ejecutó durante el cierre. Persisten avisos globales heredados: claves foráneas sin índice, numerosos índices sin uso y un índice duplicado en `public.informes_financieros`. No son introducidos por R50 y se dejan para una fase de hardening global.

Security Advisor no se declara limpio. El proyecto mantiene deuda global histórica documentada en versiones anteriores. La corrección específica R50 de `search_path` sí está verificada en vivo.

No se realizó deploy de frontend a Netlify ni push a GitHub.
