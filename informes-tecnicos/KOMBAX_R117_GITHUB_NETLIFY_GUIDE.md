# KOMBAX R117 — GitHub + Netlify

R117 corrige el fallo por ausencia de `android/app/google-services.json` en GitHub/Netlify.

## GitHub

Sustituye el contenido del repositorio por R117 y realiza tu commit/push habitual. No fuerces la inclusión de:

- `android/app/google-services.json`
- `android/keystore.properties`
- `*.jks`
- `*.keystore`
- `.env*`

El `.gitignore` ya los protege.

## Verificación local

```bat
KOMBAX_R117_VERIFY_LOCAL.cmd
```

## Netlify

`netlify.toml` mantiene:

- build: `npm run release:build`
- publish: `dist`

El gate ha sido probado expresamente sin `google-services.json` y pasa.

Para despliegue por CLI, una vez enlazado al sitio KOMBAX correcto:

```bat
KOMBAX_R117_DEPLOY_NETLIFY.cmd
```
