# KOMBAX RC13 build 20067 · Deploy + Android Signed Readiness

## Resultado

**APTA como candidata de deploy Netlify y generación de APK/AAB signed**, con una única dependencia local deliberada: la firma Android histórica.

## Netlify

- `netlify.toml`: `command = "npm run build"`, `publish = "dist"`.
- Node configurado: 22.
- El comando exacto de Netlify se ha ejecutado correctamente.
- `dist` se genera desde `web` y queda idéntico.

## Android

- applicationId: `com.urbanwarriors.app`
- versionCode: `20067`
- versionName: `2.0.0-rc.13`
- compileSdk / targetSdk: 36 / 36
- Firebase Android: `google-services.json` presente en esta entrega local.
- Web embebida: idéntica a la build web.
- Firma: no incluida por seguridad. Usar el JKS histórico y el alias ya utilizados en releases anteriores.

## Owner

- 8 taps / 5 s para puerta oculta móvil.
- Correo Owner + contraseña.
- Sin OTP de correo en Acceso Maestro.
- v108 + v110 activos en Supabase LIVE.

## Prueba posterior obligatoria

Tras publicar/instalar, comprobar con credenciales reales Owner que la Consola KOMBAX abre sin enviar correo OTP. Comprobar también una cuenta QA normal y un Club QA para no confundir privilegios Owner con permisos internos de club.
