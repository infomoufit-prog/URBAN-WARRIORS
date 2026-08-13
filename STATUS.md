# Estado del proyecto

## Estado actual

- Release activa de trabajo: **fase de integración Supabase previa a APK**.
- Código funcional: **Releases B–J implementadas localmente**.
- Pruebas locales: **superadas**.
- Supabase real: **migraciones 023–028 ejecutadas; gateway encadenado, finanzas/material/avisos activos, índice Comunidad y metadatos 028 verificados**.
- Certificación E2E Gestor del backend: **19/19 OK, ejecutada desde la interfaz RC12 instalada**.
- Vista previa web RC10: **certificada con diagnóstico y CRUD crítico**.
- Web/PWA publicada: **RC12; restauración RC10 preparada y pendiente de fusión controlada**.
- Android físico instalado: **RC12 detectada; RC10 pendiente de generar e instalar**.
- Producción web: **sin nuevos cambios; no se desplegará hasta cerrar la reconstrucción**.
- Supabase: **migraciones 023–028 activas; migraciones 029–030 y Edge Functions posteriores preparadas solo en local**.

## Punto de retorno

El ZIP RC10 original, identificado en `BASELINE_RC10.md`, es el punto de retorno inmutable.

## Bloque permitido actualmente

Implementación local controlada sobre RC10. No se fusionará ni desplegará web hasta completar migraciones, Edge Functions, Android Studio, APK, dispositivo real y regresión.

## Bloque siguiente

Aplicar 029–030 en Supabase, ejecutar diagnóstico/CRUD real por roles y desplegar/probar las Edge Functions antes de abrir Android Studio. No habrá fusión ni Netlify durante esta fase.

Siguiente paso externo: ejecutar el preflight 029 antes de ampliar vídeo, bucket y portadas.

Paquete previo completo: `PREDEPLOY_EXECUTION.md`, con preflight/verificación 029–030,
auditoría conjunta 023–030, salud backend previa a APK y orden Edge → CRUD/RLS → Android → Netlify.
