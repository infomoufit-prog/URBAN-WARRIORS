# Procedimiento final RC9 · un solo deploy

1. Mantener la versión publicada mientras se valida RC9 localmente.
2. En Supabase SQL Editor ejecutar **una sola vez** `SQL_EJECUTAR_RC9_021.sql` después de 020.
3. Confirmar que `app_diagnostico_final_v165()` devuelve controles `OK` con la cuenta Gestor de la app.
4. En la carpeta RC9 ejecutar `npm install`, `npm test`, `npm run build`, `npm run dev`.
5. Probar login del Gestor de la app: debe conservar todas las operaciones, Herramientas técnicas y `Eliminar todo`.
6. Crear una invitación de prueba con rol **Coordinación**, aceptarla con otra cuenta y verificar: panel operativo completo, sin E2E/diagnóstico, sin crear invitaciones y sin `Eliminar todo`.
7. Tras la certificación, en el repositorio local `URBAN-WARRIORS` conservar `.git` y sustituir el resto por el contenido del ZIP RC9 limpio.
8. Hacer un único commit y `Push origin`. Netlify publicará automáticamente.
9. Validar producción y congelar funcionalidades antes de firma APK/AAB.
