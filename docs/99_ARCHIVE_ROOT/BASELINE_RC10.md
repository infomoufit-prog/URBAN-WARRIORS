# Baseline RC10

## Identidad

- Fuente: `URBAN-WARRIORS-2.0.0-RC10-FINAL-MVP-MANUALES-VISUALES-SQL022-FIX-GITHUB-LIMPIO.zip`
- SHA-256 del ZIP: `9ce305c73978b87e5644d796baa3e9c81a57d56d11a992205a4fdf66211d936a`
- Aplicación: `2.0.0-rc.10`
- Android: `versionCode 20010`
- Backend: `1.6.0`
- Schema epoch: `160`
- Gateway de escritura: `app_mutate_v160`
- Migración final incluida: `022_rc10_final_mvp_v166.sql`

El ZIP original permanece congelado. Todo cambio futuro se realizará únicamente sobre la copia de trabajo.

## Certificación local

| Control | Estado | Evidencia |
|---|---|---|
| Integridad ZIP | Superado | `unzip -t`: sin errores |
| Manifiesto SHA-256 interno | Superado | todos los archivos declarados coinciden |
| Suite estática | Superado | `npm test` |
| Contrato de mutaciones | Superado | 74/74 operaciones detectadas |
| Build compartido | Superado | `npm run build` |
| Paridad frontend | Superado | `web = dist = android/app/src/main/assets/www` |
| Arquitectura sin store paralelo | Superado | pruebas de arquitectura RC10 |
| Diagnóstico Supabase real | Superado | migración 023 aplicada; 12/12 OK |
| Escrituras reales Gestor | Superado con alcance backend | certificación E2E 19/19 desde interfaz RC12 |
| Web/PWA RC10 | Pendiente | Netlify sirve actualmente RC12 |
| Push real | Pendiente | requiere Edge Functions, FCM y Pixel 8 |
| APK física | Pendiente | requiere Android Studio, keystore existente y dispositivo |

## Matriz funcional pendiente de certificación real

| Área | Gestor | Coordinación | Secretaría | Alumno | Familia |
|---|---:|---:|---:|---:|---:|
| Login y restauración | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Comunicaciones: leer | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Comunicaciones: crear/publicar | Pendiente | Pendiente | Pendiente | No permitido | No permitido |
| Comunidad: leer/publicar | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Comunidad: eliminar/moderar | Pendiente | Pendiente | Pendiente | Propia pendiente | Propia pendiente |
| Finanzas | Pendiente | Pendiente | Pendiente | Propia pendiente | Vinculada pendiente |
| Material | Pendiente | Pendiente | Pendiente | Solicitud pendiente | Solicitud pendiente |
| Push | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |

## Criterio de aprobación

RC10 solo pasará de `pruebas locales superadas` a `aprobado` cuando se hayan validado Supabase real, los CRUD por rol, la web/PWA y la APK física. No se aplicarán mejoras funcionales sobre producción antes de completar esta certificación.

## Evidencia Supabase 2026-08-13

`app_diagnostico_instalacion_v166()` devuelve 11 controles `OK` y un `FALLO`:

- Control: `notificaciones masivas`.
- Detalle: `leer grupos/todas`.

Antes de aplicar una migración debe inspeccionarse la definición activa de `app_mutate_v160` para distinguir entre una instalación incompleta de SQL022 y una sustitución posterior del gateway.

La inspección posterior confirma que la función activa tiene aproximadamente 10.182 caracteres y no contiene `notificacion.leer_grupo`, `notificacion.leer_todas` ni `notificaciones.preferencias`. La copia histórica `app_mutate_v160_v166`, de aproximadamente 17.877 caracteres, sí contiene las operaciones RC10 comprobadas. El gateway activo no coincide con la definición RC10 incluida en SQL022.

La migración controlada `023_restore_rc10_gateway_v166.sql` se ejecutó posteriormente. Conservó el gateway anterior como `app_mutate_v160_pre_restore_023`, promovió la copia RC10 `_v166` y obtuvo **12/12 controles OK**.

La certificación E2E se ejecutó desde la aplicación real con cuenta Gestor. Resultado comunicado: **todo OK (19/19)**. El flujo incluyó contrato, diagnóstico, disciplinas, grados, grupos, tarifas, alumno, sesiones, asistencia, seguimiento, comunicación, material, Storage privado, recurrencias, Comunidad, ciclo de vida, logout/login, persistencia y limpieza final.

Después se confirmó que tanto la APK instalada como el frontend publicado en Netlify correspondían a RC12. Por tanto, el resultado 19/19 certifica el gateway/backend RC10 recuperado frente a esos flujos, pero no constituye certificación visual o funcional del frontend RC10. Release A permanece abierta hasta restaurar y probar RC10 en web y Android.
