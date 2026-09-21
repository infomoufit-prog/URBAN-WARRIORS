# KOMBAX RC13 build 20.100 · Brand Heroes · Validación

## Objetivo
Unificar la identidad de portada de KOMBAX Social, KOMBAX Events y KOMBAX Showcase sin inventar logos nuevos y sin alterar los dominios funcionales heredados de 20.099.

## Implementación
- `web/js/ui/brand-hero.js`: componente hero común.
- `web/css/kombax-brand-heroes.css`: sistema de layout, color, motion y responsive.
- `web/assets/brand-heroes/hero-social.webp`: 1600×720.
- `web/assets/brand-heroes/hero-events.webp`: 1600×720.
- `web/assets/brand-heroes/hero-showcase.webp`: 1600×720.
- logo oficial mediante `KOMBAX_BRAND.symbol` (`kombax-symbol-white.png`).

## Copy final
- Social: `Tu red. Tu legado.`
- Events: `El espectáculo no empieza en el ring. Empieza aquí.`
- Events claim: `FROM HYPE TO HISTORY`.
- Showcase: `Muestra. Promociona. Destaca.`

## Invariantes preservados
- Events mantiene `Explorar eventos` y `Crear evento` con IDs/handlers existentes.
- Large Format 20.098 permanece.
- Álbum oficial 20.099 (15 fotos + 5 vídeos HD/60 s) permanece.
- Workspace Isolation 20.097 permanece.
- Social/Mi red y Showcase no cambian backend ni reglas.
- Mi Club > Eventos sigue separado de KOMBAX Events.
- No se añaden migraciones Supabase en 20.100.

## QA
- `node --check web/js/ui/brand-hero.js`: PASS.
- test 20.096: PASS.
- test 20.098: PASS.
- test 20.099: PASS.
- test 20.100: PASS.
- `npm test`: PASS completo hasta 20.100.
- `npm run build`: PASS.
- resultado build: `OK build 107 archivos · web = dist = Android`.
- legal gate: PASS.
- Android preflight: 4/5; único pendiente `android/keystore.properties` local con credenciales.
- Android versionCode: 20100.

## Ajuste de regresión heredada
`test-kombax-20088-finance-mobile-responsive.mjs` estaba congelado a cache-busting 20090–20099. Se amplió exclusivamente la regex de identidad para admitir 20100+; todas las aserciones funcionales de Finance permanecen intactas.

## Firma Android
- JKS solicitado incluido en `LOCAL_RELEASE_SIGNING/kombax-release.jks`.
- SHA-256 JKS: `7c70adc0d8e7b9426990d86a3f4743e2794e391f725dd708082e48264183a415`.
- no se almacenan contraseñas ni `android/keystore.properties` real.

## Backend / producción
- 20.100 no necesita DDL/RPC/Edge Functions nuevos.
- backend funcional de Events continúa en el estado 20.099 (migraciones 175/176 previamente aplicadas).
- source local `health` está versionado 20100 para un deploy posterior; no debe publicarse como 20100 antes de desplegar la frontend correspondiente.
- no se ha hecho deploy Netlify ni Google Play en esta intervención.
