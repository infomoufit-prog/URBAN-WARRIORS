# KOMBAX 20.101 R33.1 — entrega preparada

Fecha de preparación: 2026-09-01

## Resultado verificable

- Puerta legal: `PASS`.
- Pruebas previas de seguridad, privacidad, recuperación, salud y soporte: `PASS`.
- Suite principal: 154 ficheros de prueba ejecutados, `PASS`.
- Build: 184 ficheros; paridad `web = dist = Android`, `PASS`.
- Android preflight: 4/5.
- Revisión de secretos: no se encontraron claves privadas, `service_role`, keystores ni archivos `.env`.

## Corrección de preparación

Se corrigió la resolución de rutas en once pruebas para que funcionen en Windows cuando la ruta contiene espacios. El cambio afecta únicamente al arnés de pruebas; no modifica frontend, Android, Supabase, permisos ni datos.

## Netlify

- Node configurado: 22.
- Build: `npm run release:build`.
- Publicación: `dist`.
- `netlify.toml` conserva CSP, cabeceras de seguridad, rutas legales y fallback SPA.
- Estado: construido y probado localmente; no desplegado desde este entorno.

## Android / Google Play

- `applicationId`: `com.urbanwarriors.app`.
- `versionCode`: `20101`.
- Assets web y Firebase presentes.
- Falta `android/keystore.properties` y la clave de upload/release externa.
- No se ha generado ni se declara un AAB firmado.

En una estación autorizada con JDK, Android SDK y la clave existente, crear `android/keystore.properties` a partir del ejemplo y ejecutar el wrapper Gradle para generar el bundle release. La clave nunca debe entrar en el ZIP ni en Git.

## Supabase

El proyecto principal `poggsobhtutbuagjiydc` fue consultado directamente. La migración R33.1 estaba aplicada y el 2026-09-01 se añadió la migración `20260901070443_kombax_customer_operations_email_first_v030`. Crea seis tablas en el esquema privado `kombax_customer_ops`, todas con RLS y sin permisos para `PUBLIC`, `anon`, `authenticated` o `service_role`. El fichero de migración live se incluye en `supabase/migrations/`.

## Estados que no se declaran

- Netlify: `NOT DEPLOYED`.
- Supabase Customer Operations: `SCHEMA DEPLOYED, FAIL-CLOSED`.
- Android signed: `NOT BUILT`.
- Google Play: `NOT UPLOADED / NOT RELEASED`.
