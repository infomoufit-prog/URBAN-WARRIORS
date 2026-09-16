# QA Handoff · KOMBAX 20.101 R53 · Build 20103

## Preparación local
Usar Node/npm compatible con el proyecto y Java 17 para Android.

```powershell
npm install
npm test
npm run dev
```

## Web/PWA
Abrir el host que muestre `npm run dev` y validar:
- Buscar perfiles → Añadir a mi red.
- Perfil público → CTA de red.
- Álbum Todo/Fotos/Vídeos.
- Últimas 5 publicaciones.
- Showcase del perfil.
- KOMBAX Events.
- Vídeos con portada y apertura del contenido completo.

## Android debug
```powershell
npm run android:preflight
npm run android:debug:qa
```

Salidas esperadas:
- `android/app/build/outputs/apk/debug/app-debug.apk`
- `artifacts/KOMBAX_20103_R53_PILOT_DEBUG.apk`

Instalar el APK y repetir los mismos flujos de Web/PWA, poniendo especial atención a la portada de vídeo en publicaciones KOMBAX Social.

## Google Play / AAB
Antes del bundle, configurar **solo localmente** el material legítimo de firma según `android/keystore.properties.example`.

```powershell
npm run android:preflight
npm run android:aab:play
```

Salida esperada:
- `artifacts/KOMBAX_20103_R53_PILOT_GOOGLE_PLAY.aab`

No compartir ni incorporar el keystore al ZIP de código.

## Evidencia de esta entrega
- `QA_FULL_20103_R53.log` → EXIT 0.
- `ANDROID_PREFLIGHT_20103_R53.log` → 4/5; firma local pendiente.
- `ANDROID_DEBUG_BUILD_20103_R53.log` → sincronización correcta y bloqueo externo DNS al descargar Gradle en el entorno de auditoría.
- `R53_PARITY_REPORT.json` → 191/191/191, 0 diferencias.

## Checklist manual mínimo
- Miembro→Miembro / Miembro→Club: solicitar, aceptar/rechazar, evitar duplicado y eliminar.
- Perfil público de cada tipo disponible: privacidad, álbum, 5 últimas publicaciones, Showcase.
- Events: crear/editar, visibilidad, participantes, Fight Card, álbum y vídeo.
- Portadas: Álbum → Social → APK; portada visible antes de reproducir y vídeo original completo al abrir.
- Notificaciones/navegación básica y sesión autenticada.
