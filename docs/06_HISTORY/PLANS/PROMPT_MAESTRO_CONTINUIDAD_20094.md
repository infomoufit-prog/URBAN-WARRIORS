# PROMPT MAESTRO DE CONTINUIDAD — KOMBAX RC13 20.094 → 20.095

Trabaja exclusivamente sobre **KOMBAX RC13 build 20.094 LIVE + RESULTS + HIGHLIGHTS + HISTORY** como nueva fuente de verdad.

## Estado cerrado 20.094
- KOMBAX Eventos público/transversal separado de `Mi Club > Eventos`.
- Live + estados temporales, resultados provisional/oficial/anulado, álbum/highlights privado con URL firmada, deep-links anónimos e historial oficial Competidor.
- Supabase productivo migraciones 164–170 aplicadas y verificadas.
- `health` v14 / build 20094 ACTIVE.
- `event-media-url` v1 ACTIVE.
- `npm test` PASS y `npm run build` PASS.
- web = dist = Android: 101 archivos.

## Misión 20.095 — Integration / Hardening Final Candidate
No añadir grandes features. Integrar y endurecer la candidata para validación real de producción:
1. Auditoría transversal de navegación y deep-links web/PWA/Android.
2. Regresión de autenticación, perfiles, Social, Showcase, Finanzas Premium, notificaciones/push y Eventos.
3. Revisar expiración/errores de media firmada y UX offline/degraded.
4. Validar seguridad focalizada de RPC/Edge/Storage sin tocar el baseline heredado salvo riesgo real.
5. Validar responsive/rotación Android y lifecycle de sesión.
6. Preparar candidato Netlify sin desplegar automáticamente.
7. Preparar Android para APK signed y AAB/Google Play sin generar ni sustituir keystore.
8. Ejecutar `npm test`, `npm run build`, paridad web/dist/Android, manifest SHA-256 y ZIP final.

## Reglas innegociables
- NO mezclar KOMBAX Eventos con las tablas privadas de `Mi Club > Eventos`.
- NO copiar alumnos, participantes o históricos privados hacia Eventos públicos.
- NO reabrir writes directos a tablas Events: mantener gateways/RPC.
- NO hacer público `kombax-events-media`; mantener firmador temporal server-side.
- NO permitir que `event.fight.save` escriba resultados; usar `event.fight.result.set`.
- NO activar perfil Espectador en 20.095; continúa pendiente del gate edad/privacidad.
- NO romper Finanzas Premium, Social, Showcase, notificaciones, Owner/Admin o flujos Android existentes.
- NO hacer deploy Netlify ni publicar Google Play sin instrucción explícita del usuario.
