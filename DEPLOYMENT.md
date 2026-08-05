# Despliegue de Urban Warriors

## Arquitectura de publicación recomendada

1. **Supabase:** autenticación, PostgreSQL, RLS, Storage, Edge Functions y Cron.
2. **Netlify:** web/PWA y página pública de descarga.
3. **GitHub Releases:** APK firmado y versionado. Como alternativa, bucket público `app-releases` de Supabase Storage.
4. **QR:** siempre apunta a la página estable de Netlify `/#/download`. La página se actualiza cuando cambia el APK, sin reimprimir el cartel.

## 1. Crear Supabase

1. Crea un proyecto europeo y guarda la URL y la clave pública `anon`.
2. Ejecuta las migraciones `001` a `004` en orden.
3. Crea el bucket privado `justificantes-pago`.
4. No ejecutes `seed.sql` en producción salvo que se revise previamente.
5. Configura en Auth la URL pública de Netlify y sus redirecciones.
6. Crea las primeras cuentas de dirección/secretaría y sus membresías.
7. Comprueba RLS con dos usuarios y, preferentemente, dos clubes de prueba.

## 2. Activar la app real

En `web/config.js`:

```js
  demoMode: false,
  supabase: {
    enabled: true,
    url: 'https://TU-PROYECTO.supabase.co',
    anonKey: 'TU_ANON_KEY'
  }
```

Ejecuta:

```bash
npm test
npm run build
```

## 3. Desplegar la web en Netlify

El repositorio incluye `netlify.toml`.

- Build command: `npm run build`
- Publish directory: `dist`

Tras el primer despliegue, actualiza:

```js
release: {
  webUrl: 'https://TU-SITIO.netlify.app',
  apkUrl: ''
}
```

Luego vuelve a construir y desplegar.

## 4. Programar los cinco avisos

Despliega la función:

```bash
supabase functions deploy payment-reminders --no-verify-jwt
```

Configura secretos:

```bash
supabase secrets set UW_CRON_SECRET='SECRETO_ALEATORIO'
```

Si se activa Firebase:

```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"project_id":"..."}'
```

Adapta y ejecuta `supabase/cron_payment_reminders.sql.example`. El cron llama cada hora; la función procesa cada club solo cuando coincide con su hora local configurada.

## 5. Publicar APK y QR

1. Genera un APK firmado siguiendo `ANDROID.md`.
2. Publícalo como versión, por ejemplo `urban-warriors-1.2.0.apk`.
3. Copia su URL HTTPS en `release.apkUrl`.
4. Genera el QR de la página estable:

```bash
python3 scripts/generate_qr.py 'https://TU-SITIO.netlify.app/#/download'
npm run build
```

5. Vuelve a desplegar Netlify y sustituye el QR provisional del cartel.

## Dirección final sugerida

Primero puede utilizarse el subdominio gratuito de Netlify. Cuando el gimnasio confirme el regalo, puede conectarse un dominio o subdominio como `app.urbanwarriors.es`, si el club dispone de ese dominio.
