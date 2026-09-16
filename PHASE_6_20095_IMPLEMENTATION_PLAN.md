# KOMBAX RC13 · Fase 6 / build 20.095 · Integration / Hardening Final Candidate

## Objetivo
Convertir 20.094 en candidata final de integración para validación real en Netlify y Android, sin introducir grandes funcionalidades ni hacer despliegues/publicaciones automáticas.

## Principios
1. Mantener KOMBAX Eventos público separado de `Mi Club > Eventos`.
2. No activar Espectador; sigue pendiente de gate edad/privacidad.
3. No modificar Finanzas Premium, Social, Showcase, Owner/Admin o notificaciones salvo corrección de regresión demostrada.
4. Mantener Storage de Eventos privado y resultados por ruta dedicada.
5. Cualquier hardening debe tener test/regresión.

## Fases de trabajo
1. Reconciliar identidad 20095 en web/PWA/Android/health.
2. Auditar navegación/deep-links y arranque anónimo/autenticado en PWA + Android WebView.
3. Auditar Netlify headers/redirects y comportamiento SPA/deep-link.
4. Auditar degradación/offline de media firmada y evitar roturas si una URL expira/no carga.
5. Auditar Android: versionCode, orientación, assets, network/security config y readiness APK/AAB.
6. Ejecutar seguridad focalizada RPC/Edge/Storage; no tocar baseline heredado sin evidencia de riesgo.
7. Ejecutar `npm test`, `npm run build` y paridad web/dist/Android.
8. Generar documentación, manifiesto SHA-256, ZIP final 20.095 y prompt de validación Netlify/APK/AAB.

## No hacer
- No deploy Netlify.
- No publicar Play Store.
- No generar/reemplazar keystore.
- No activar perfil Espectador.
- No mezclar datos privados del club con KOMBAX Eventos.
