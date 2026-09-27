# KOMBAX R89 build 20142 — Certificación de entrega pre-piloto

## Propósito

Certificar la base acumulativa destinada a continuidad de repositorio, despliegue Netlify y generación local de APK/AAB para el piloto.

## Base vigente

- Release: R89
- Build: 20142
- Version: 2.0.0-rc.13-r89-inventory-lifecycle
- Android applicationId: com.urbanwarriors.app
- compileSdk / targetSdk: 36 / 36
- Netlify publish: dist
- Netlify build: npm run release:build

## Gates ejecutados sobre una extracción limpia del paquete

- ZIP CRC: PASS
- `npm test`: PASS
- `npm run release:build`: PASS
- R89 contract gate: 52/52 PASS
- Web = dist = Android assets: 556 archivos
- Android preflight sin firma local: 4/5; único pendiente intencional = keystore local
- Supabase R89 live: migración aplicada y RPC verificadas
- Supabase health: build 20142 ACTIVE
- API objetivo Google Play: 36

## Última milla Android corregida

Los helpers operativos ya no generan nombres históricos R62.8:

- APK QA: `KOMBAX_20142_R89_PILOT_QA_DEBUG.apk`
- AAB Play: `KOMBAX_20142_R89_PILOT_GOOGLE_PLAY.aab`

El helper AAB ejecuta `npm run release:build` antes del preflight y de `bundleRelease`.

## Firma y Google Play

La clave de subida no se distribuye. Para producir el binario publicable se debe configurar localmente `android/keystore.properties` y ejecutar:

```bash
npm run android:preflight
npm run android:aab:play
```

El preflight debe terminar 5/5. Después se debe subir el `.aab` generado a la pista interna/cerrada correspondiente de Play Console.

## GitHub

La raíz está preparada como repositorio fuente. `.gitignore` excluye secretos, firma y binarios generados. La documentación histórica permanece para trazabilidad, pero R89/20142 es la única base vigente.

## Netlify

`netlify.toml` ejecuta el mismo release gate que se usa para certificar localmente y publica `dist`.

## Limitación del entorno de certificación

No se pudo ejecutar la descarga de Gradle 8.11.1 en este entorno por resolución de red hacia `services.gradle.org`. No se declara por tanto que exista un AAB firmado ya compilado dentro del ZIP. El código fuente, configuración de versión y helper de generación quedan listos para ejecutarse en el ordenador local con Android Studio/Gradle.

## Veredicto de entrega

Apto como **base acumulativa fuente** para GitHub, Netlify y Android Studio. Apto para generar el AAB de Google Play una vez restaurada la firma local y completado el preflight 5/5. El archivo que se sube a Play Console es el AAB firmado generado localmente, no este ZIP.
