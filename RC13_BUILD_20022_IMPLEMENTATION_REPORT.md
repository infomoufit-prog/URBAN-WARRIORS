# RC13 build 20022 · informe de implementación

## Alcance cerrado

Build de estabilización de Urban Warriors sobre la base Android 20021. Conserva `applicationId com.urbanwarriors.app`, `versionName 2.0.0-rc.13`, nombre e icono instalados. Añade el símbolo KOMBAX como co-marca secundaria.

## Implementado

- Notificaciones: centro unificado 037, lectura persistente para avisos dirigidos y compartidos, actualización optimista y rollback visual.
- Identidad: composición segura de nombre y apellidos.
- Rendimiento: caché aislada por `club_id + perfil_id`, invalidación tras mutaciones y observación P50/P95/>5 s.
- Contenido: estados `activo`, `archivado` y `papelera`; recuperación durante 30 días; auditoría; filtros por tipo/estado/fecha; selección múltiple del mismo tipo.
- Tipos cubiertos: publicaciones, comunicaciones, eventos, notificaciones informativas, material, documentos, seguimiento, asistencias y sesiones finalizadas.
- Finanzas: recibo profesional sobre `recibos_cuota`, sin contabilidad paralela. Los registros financieros no participan en el borrado genérico.
- Branding: temas Combat Dark, Performance Pro, Champion Gold y Dojo Heritage; vista previa, control de versión, publicación y restauración.
- Distribución: `web`, `dist` y assets Android sincronizados por el build reproducible.

## Evidencia local

- Suite estática completa: 32 scripts, exit code 0.
- Sintaxis de todos los módulos `web/js`: exit code 0.
- `scripts/build.mjs`: 55 archivos, hashes idénticos entre `web`, `dist` y Android.
- `git diff --check`: sin errores.

## Estados que no deben confundirse con validación real

- Migraciones 037–039 en Supabase real: **NO EJECUTADO**.
- Pruebas SQL transaccionales 037–039: **PENDIENTE DE ENTORNO**.
- Validación visual manual del build 20022: **PENDIENTE**.
- Compilación Android Gradle: **PENDIENTE DE ENTORNO**.
- Firma con JKS y verificación pública: **PENDIENTE DE AUTORIZACIÓN / ENTORNO**.
- APK/AAB e instalación encima de 20021: **VALIDACIÓN FÍSICA PENDIENTE**.
- Netlify: **NO DESPLEGADO**.

## Orden de backend propuesto

Ejecutar únicamente tras autorización: preflight 037 → migración 037 → verificación/prueba; repetir para 038 y 039. No ejecutar rollbacks salvo incidencia confirmada. La migración 038 no contiene borrado físico y la 039 conserva historial de branding.
