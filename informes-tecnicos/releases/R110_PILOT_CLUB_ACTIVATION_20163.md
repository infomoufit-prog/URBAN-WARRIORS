# Release R110 · build 20163

Versión: `2.0.0-rc.13-r110-pilot-club-activation`.

Incluye alta temporal Club Piloto, cuatro plazas con códigos Owner de un solo uso, validación automática sin documentación, Premium piloto, continuidad como fundador elegible, métricas Owner ampliadas y copy R110 en los ocho idiomas soportados.

Supabase: migración `kombax_pilot_club_activation_owner_r110` aplicada en el proyecto activo el 29/09/2026. Estado leído tras despliegue: ventana abierta, 4 plazas, 0 usadas, 0 reservadas, documentos no requeridos y Club persistente después del piloto.

QA: R110 32/32 PASS; R100, R102, R32, R58 y R62.6 PASS; R109 semantic gate 25/25 PASS tras hacerlo compatible con builds acumulativos posteriores. All-8 i18n PASS. Auditoría R79: 255 unresolved históricos frente a 264 en R109, por lo que no hay regresión. Build: 619 archivos; `web = dist = Android`.

Pendiente externo: Gradle 8.11.1 no está cacheado y el entorno no puede resolver `services.gradle.org`, por lo que APK/AAB requiere compilación externa.
