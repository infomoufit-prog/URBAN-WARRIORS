# KOMBAX RC13 · build 20038

## Intervención
- Corrige selector Tipo del álbum (Fotografía/Video).
- Defensa adicional: normaliza tipo por MIME antes de subir al backend.
- Corrige RLS de ruta `<uid>/club/<club_id>/<archivo>` (3 carpetas).
- Sincronización canónica del logo/portada del perfil público de Club con KOMBAX Social y backfill.
- Lecturas Social usan URL efectiva del Club aunque una materialización quede obsoleta.
- Foto Social explícita prevalece sobre URL heredada.
- Self-heal seguro de avatar histórico de Miembro: solo el propio usuario puede copiar su foto privada a su avatar público.
- Feed de KOMBAX Social conserva proporción original de fotos; se elimina zoom que podía recortar bordes.
- Álbum y perfil público permiten abrir la foto completa sin recorte.
- Publicador revierte archivos nuevos si falla la publicación.
- Auditoría de selectores legacy en superficies Club/Public/Social/Platform Admin.

## Validación final ejecutada
- Suite histórica completa + regresión 20038: PASS.
- Build: 62 archivos idénticos entre web, dist y Android.
- Supabase 063 + 064 aplicadas y verificadas live.
- Prueba transaccional `photo` aceptado / tipo inválido rechazado: PASS.
- Deduplicación y rollback al reutilizar álbum: PASS por regresión.
- Android preflight: 4/5; firma JKS sigue pendiente deliberadamente.
- El paquete fuente 20038 no incluye secretos de firma.
