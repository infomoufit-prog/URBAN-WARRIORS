# Procedimiento final RC10 · un solo deploy

> **HISTÓRICO / NO USAR PARA BUILD 20025.** Para la candidata actual consultar `DOCUMENTATION_INDEX.md` y `NETLIFY_KOMBAX_BUILD_20025_RUNBOOK.md`.

1. Mantener RC9 publicada mientras se certifica RC10.
2. En Supabase SQL Editor ejecutar **una sola vez** `SQL_EJECUTAR_RC10_022.sql`, después de 021/021B ya validados.
3. El propio SQL termina mostrando `app_diagnostico_instalacion_v166()`: comprobar **12 controles en OK**.
4. En la carpeta RC10 ejecutar `npm install`, `npm test`, `npm run build` y `npm run dev`.
5. Entrar como **Gestor de la app** y ejecutar la certificación E2E completa.
6. Probar manualmente: notificaciones masivas, serie semanal y excepción, reserva, Comunidad, avatar, Finanzas/estado de cuenta, textos legales y Ayuda.
7. Tras la certificación, en el repositorio local `URBAN-WARRIORS` conservar únicamente `.git` y sustituir el resto por el contenido del ZIP RC10 limpio.
8. GitHub Desktop: un único commit y `Push origin`. Netlify publicará automáticamente.
9. Validar la URL de producción.
10. Configurar/certificar push en Android con `PUSH_PRODUCCION_CHECKLIST.md`.
11. Congelar funcionalidades y promover a `2.0.0` antes de generar APK/AAB release firmado.
