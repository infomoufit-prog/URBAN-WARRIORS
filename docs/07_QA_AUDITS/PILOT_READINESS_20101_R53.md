# KOMBAX 20.101 R53 · Pilot Readiness

## Identidad
- Revisión: **R53 · PILOT_NETWORK_PUBLIC_PROFILES_EVENTS_STABILIZATION**.
- Build web/Android: **20103**.
- Android versionName: **2.0.0-rc.13-r53-pilot**.
- `applicationId`: `com.urbanwarriors.app`.
- R51 permanece como baseline histórica congelada; R53 es una derivada candidata a piloto.

## Implementación incluida
- Mi red universal y privada para perfiles públicos activos/visibles.
- Perfil público universal: CTA de red, álbum Todo/Fotos/Vídeos, últimas 5 publicaciones y Showcase.
- Hardening de errores de KOMBAX Events.
- Conservación y regresión de las correcciones de portadas de vídeo R52/R52.2.
- Versionado Android/PWA 20103 y pipeline común de assets.

## Evidencia automática
- R53 focal: **21/21 PASS**.
- Suite completa `npm test`: **EXIT 0**.
- Web/Dist/Android: **191 / 191 / 191**.
- Diferencias SHA: **0**.
- Android preflight: **4/5**.

## Backend vivo
- Migración R53 de Mi red aplicada en Supabase principal.
- Edge Function `health` actualizada a build 20103.

## Estado por superficie
### WEB/PWA — PASS técnico
Código probado, build generado y paridad web/dist confirmada. No se ha desplegado Netlify en esta intervención.

### APK ANDROID — READY TO BUILD / QA LOCAL PENDIENTE
El runner sincroniza 191 assets e invoca Gradle correctamente. En este entorno, Gradle no puede descargar `gradle-8.11.1-bin.zip` por `UnknownHostException: services.gradle.org`, por lo que **no se incluye un APK físico generado aquí**. En un PC con Gradle/caché o Internet, ejecutar:

```powershell
npm run android:debug:qa
```

Salida esperada:
- `android/app/build/outputs/apk/debug/app-debug.apk`
- `artifacts/KOMBAX_20103_R53_PILOT_DEBUG.apk`

### GOOGLE PLAY — PREPARADO 4/5 / FIRMA PENDIENTE
Firebase, identidad, assets y versionado están preparados. Falta el archivo privado local `android/keystore.properties`; no se inventa ni se empaqueta material de firma.

Con firma local configurada:

```powershell
npm run android:aab:play
```

Artefacto esperado:
- `artifacts/KOMBAX_20103_R53_PILOT_GOOGLE_PLAY.aab`

## Gates aún abiertos antes de declarar “Production Ready”
1. QA manual autenticado en APK R53 instalada, incluyendo Mi red, perfiles, Events y portadas de vídeo.
2. Generación/firma local del AAB con el keystore legítimo.
3. Cierre explícito de Security/Performance Advisors globales. En esta sesión no se obtuvo una respuesta concluyente de Advisors y, por tanto, **no se marca PASS**.
4. Decisión expresa de despliegue/publicación.

## Despliegues no realizados
- Netlify frontend: NO.
- GitHub push: NO.
- Google Play publish: NO.

R53 queda como **candidato de piloto preparado para build local**, no como producción cerrada.
