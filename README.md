# Urban Warriors 2.0.0-rc.13 · build 20020

Candidata de validación del MVP de Urban Warriors. Esta versión continúa siendo la app del club Urban Warriors; **no despliega todavía la futura plataforma multiclub**. La arquitectura sí queda preparada para generalizar perfiles, permisos e identidad pública sin reescribir el núcleo.

## Base estable

- Backend: `1.6.0`
- Schema epoch: `160`
- Gateway único: `app_mutate_v160`
- Android package: `com.urbanwarriors.app`
- Android `versionCode`: `20020`
- Android `targetSdk` / `compileSdk`: `36`
- Cadena SQL: 023–030 histórica + 031 Finanzas + 032 Social + 033 Eventos + 034 Notificaciones + 035 Perfil público de club + 036 Acceso social/seguridad.

## Alcance build 20020

- Notificaciones accionables: lectura masiva solo de informativas; las tareas deben abrirse con **Revisar**.
- Perfil público de Urban Warriors separado del expediente administrativo.
- En **Comunidad del Club**, el **nombre del club** abre su perfil público; el logo no es el mecanismo obligatorio.
- Capa normalizada de identidad pública para `club` + `miembro`, preparada para futuros tipos sin una tabla genérica gigante.
- Base opcional de **Social Community / Comunidad General**, separada del uso normal del club; en esta fase no existe feed global.
- Elegibilidad social modelada desde 14+ con edad verificada por el club y solo rol alumno; familia/tutor no es identidad social.
- Autorregistro autónomo como alumno: 16+; menores de 16 siguen el flujo tutor/club.
- Denuncia de publicación/perfil, bloqueo, revisión, ocultación y suspensión/reactivación de acceso social con auditoría.
- Perfil deportivo, likes, Finanzas y Eventos de RC13 se conservan.

## Estado real de Supabase

Durante esta misma validación se certificaron en Supabase real 031–036. Para 034 se superó además la prueba transaccional; 035 y 036 pasaron sus verificaciones de estructura/integridad. Build 20020 **no añade nuevas migraciones SQL**.

## Validación local

```bash
npm test
npm run build
```

El build web copia una única fuente a `dist` y `android/app/src/main/assets/www`; antes del freeze debe comprobarse paridad exacta.

## Importante antes de producción

Esta candidata **no está congelada** hasta completar las pruebas manuales pendientes por roles/RLS, repetir la pasada PC/web móvil del build 20020, compilar Android release firmada, instalarla físicamente encima del build anterior y cerrar la revisión de Google Play (privacidad, Data Safety, público objetivo, UGC/seguridad infantil, ficha y AAB).

Documentos principales: `RC13_BUILD_20020_FINAL_POLISH_REPORT.md`, `RC13_BUILD_20018_IMPLEMENTATION_PLAN.md`, `PLATFORM_EVOLUTION_RULES.md`, `STATUS.md`, `RC13_VALIDATION.md`, `ANDROID.md` y `SUPABASE_RUNBOOK.md`.
