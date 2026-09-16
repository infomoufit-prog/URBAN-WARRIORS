# QA · KOMBAX 20.101 R9

## Resultado técnico
**PASS para validación local y APK.**

### Entrada
- Asset `gateway-kombax-community.webp` existe y sirve HTTP 200 en local.
- Ruta del asset resuelta desde módulo y con fallback CSS.
- Contenedor hero ya no es anulado por la regla legacy.
- Dos capas de humo presentes y animadas (`gatewaySmokeRed`, `gatewaySmokeBlue`).
- Humo decorativo no intercepta clic, scroll ni navegación.
- Cache web/PWA incrementada a R9.

### Social
- Hero Social conserva el asset original.
- Nuevo encuadre desktop y móvil aplicado.
- Peleador ampliado y desplazado hacia el centro visual.
- Motion y humo respetan `prefers-reduced-motion`.

### Events
- Noche de Impacto conserva Fight Card, Main Event y entidades.
- Main Event teaser del hero queda dentro de una zona máxima de 470 px en desktop.
- Rail de organización ocupa como máximo 43% / 500 px y ya no comparte la misma zona útil del teaser.
- Hasta 6 entidades institucionales pueden mostrarse en portada (3 organiza + 3 avala).
- En móvil el rail institucional pasa a flujo normal para evitar solapes.

### Sincronización de targets
Los siguientes archivos son idénticos por SHA-256 entre `web`, `dist` y `android/app/src/main/assets/www`:
- gateway-kombax-community.webp
- kombax-premium.css
- kombax-brand-heroes.css
- kombax-events.css
- gateway.js
- kombax-events.js

### Regresión
`npm run build` final: **PASS · 148 archivos · web = dist = Android**.

### Android preflight
4/5 preparado. El único pendiente es deliberado: `android/keystore.properties` no se distribuye con secretos. La JKS y el script de restauración permanecen en `LOCAL_RELEASE_SIGNING`.

## Gate visual manual recomendado
1. Entrada: confirmar que la foto aparece inmediatamente.
2. Entrada: observar humo rojo/azul durante 10–20 s.
3. Social: comprobar que el peleador ocupa más presencia y no invade el copy.
4. Noche de Impacto: abrir detalle y confirmar que Club Fénix / Élite / Nova Combat no se solapan con el teaser del Main Event.
5. Repetir puntos 1–4 en viewport móvil / APK.
