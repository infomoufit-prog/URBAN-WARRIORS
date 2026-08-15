# Estado del proyecto · RC13 build 20020

## Pulido final 20020

- nomenclatura visible separada: **Comunidad del Club** vs **Social Community / Comunidad General**;
- Sesiones organizadas por semana natural, con navegación anterior/actual/siguiente y próxima sesión primero;
- logo/launcher normalizado para ocupar el marco circular, con iconos PWA maskable y Android adaptive icon;
- sin migraciones SQL nuevas: Supabase 034–036 permanece como backend certificado.

## Candidata actual

- Versión: **2.0.0-rc.13**.
- Build / Android `versionCode`: **20020**.
- Base inmediata reversible: RC13 build 20018; RC13 build 20017 se conserva como referencia anterior.
- Estado: **código build 20020 certificado localmente; Supabase 034–036 aplicado/verificado; falta APK release y validación final de distribución**.
- Freeze: **NO**.
- Netlify producción: **NO desplegar todavía**.

## Implementado localmente

- 031 Finanzas conservada; 032 perfiles deportivos/likes; 033 Eventos/Competiciones.
- 034 notificaciones accionables y revisión auditada.
- 035 perfil público de club + capa normalizada de identidad/búsqueda.
- 036 autorregistro alumno 16+, base social opcional con umbral configurable por club (suelo 14), aceptación legal versionada, denuncia, bloqueo, moderación y suspensión social auditada.
- La publicación UGC interna requiere aceptación explícita vigente de Normas de Comunidad del Club; no se concede durante el registro del club.
- navegación desde el **nombre del club** en Comunidad del Club al perfil público.
- configuración Android build 20020, API 36 y AGP 8.10.1.

## Evidencia local final

- `node --check`: **57/57** JS/MJS, 0 fallos.
- `npm test`: **583 OK / 29 PASS**.
- Contrato final: **93/93** operaciones.
- `npm run build`: **51 archivos · web = dist = Android**.
- `git diff --check`: limpio.

## Supabase real

- 023–030: auditado previamente durante esta sesión.
- 031: aplicado y prueba transaccional superada.
- 032: aplicado/verificado.
- 033: aplicado/verificado.
- 034: aplicado/verificado; 8/8 `true`, revisión fuera de club 0 y prueba transaccional `Success`.
- 035: aplicado/verificado; 10/10 `true` y clubes activos sin perfil público 0.
- 036: aplicado/verificado; 22/22 `true`, contadores 0/0/0/0 y suspensiones fuera de club 0.

## Puertas restantes para freeze

1. Completar pruebas manuales pendientes por roles/RLS y privacidad (incluido menor <16 y tutor cuando se decida ejecutar esa validación).
2. Repetir pasada local build 20020 en PC y móvil tras copiar el nuevo paquete al equipo.
3. Compilar Android release firmada y AAB en Android Studio/SDK real.
4. Instalar build 20020 encima del build anterior sin desinstalar y probar APK física.
5. Validar push/foreground/background/navegación/permisos Android.
6. Revisión final Google Play: público objetivo, UGC, seguridad infantil, privacidad/Data Safety y cuenta de desarrollador.
7. Commit/tag de freeze; Netlify solo desde el mismo estado certificado.
