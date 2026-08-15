# Supabase · Runbook RC13 build 20018

## Regla principal

No ejecutar varias migraciones nuevas a la vez. Orden estricto: **034 → 035 → 036**. Si un preflight o verify falla, detenerse.

La base 031–033 ya fue aplicada y verificada previamente en el proyecto real usado para este MVP. Antes de continuar conviene disponer de backup reciente.

## 034 · Notificaciones accionables

1. Ejecutar `supabase/verification/preflight_034_notifications.sql`.
2. Todos los booleanos deben ser `true`.
3. Ejecutar `supabase/migrations/034_notifications_actionable.sql`.
4. Ejecutar `supabase/verification/verify_034_notifications.sql`.
5. Todos los booleanos deben ser `true`; los contadores de incidencias deben ser `0`.
6. Ejecutar `supabase/verification/test_034_notifications_transactional.sql`.
7. Debe terminar con aviso `034 TEST OK`; el propio script revierte sus datos de prueba.

Prueba manual mínima: usuario de equipo con informativas + accionables; “Marcar informativas como leídas” no puede ocultar las accionables y `Revisar` debe abrir su ruta.

## 035 · Perfil público de club

1. `preflight_035_club_public_profile.sql` → todos `true`.
2. `035_club_public_profile.sql` → Success.
3. `verify_035_club_public_profile.sql` → booleanos `true`; incidencias `0`.
4. Confirmar también `urls_publicas_https = true` y `clubes_activos_sin_perfil_publico = 0`.

Pruebas manuales:
- Dirección/Coordinación edita perfil público.
- Rol no autorizado no puede editar aunque fuerce la mutación.
- Los datos administrativos privados no aparecen en RPC/cliente.
- Desde Comunidad, el **nombre Urban Warriors** abre la ficha; el logo no es requisito de navegación.
- Buscador devuelve club y perfiles deportivos visibles sin abrir tablas privadas.

## 036 · Acceso social, edad y seguridad

1. `preflight_036_social_access.sql` → todos `true`.
2. `036_social_access_safety_age.sql` → Success.
3. `verify_036_social_access.sql` → todos los booleanos `true`; todos los contadores de incidencias `0`.

Pruebas manuales:
- autorregistro alumno <16 rechazado por backend; 16+ mantiene preinscripción histórica;
- familia/tutor no ve activación de Comunidad General;
- alumno activo con edad verificada es la única fuente de elegibilidad; el umbral se toma de `config_club.edad_min_comunidad_general` y conserva suelo 14;
- activación exige normas + privacidad y deja aceptación legal;
- denunciar publicación/perfil y bloquear funcionan;
- moderador revisa, oculta, suspende/reactiva acceso social y queda auditoría;
- usuario suspendido no puede auto-reactivarse.

## Contrato final esperado

El frontend build 20018 exige 19 capacidades añadidas desde 032–036. Si falta alguna, el login/restauración debe fallar de forma explícita en lugar de operar contra un backend incompleto.

## Después de SQL

No desplegar todavía. Ejecutar pruebas por rol/RLS, PC, móvil web y APK física. Solo después del freeze se permite tag/push/Netlify.
