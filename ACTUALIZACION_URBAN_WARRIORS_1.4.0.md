# Actualización Urban Warriors 1.4.0

## 1. Supabase

Ejecutar una sola vez:

`supabase/migrations/009_final_operational_v140.sql`

No repetir las migraciones 001–008.

## 2. GitHub

Descomprimir el parche, subir todo su contenido interior con **Add file → Upload files** y confirmar en `main`.

## 3. Netlify

Esperar a que el despliegue aparezca como **Published**. Abrir la app en incógnito o borrar caché/datos del sitio.

## 4. Prueba inicial

Preinscripción → lista de espera → aprobación → socio activo. Después probar grupo con horarios, cuota, cobro, publicación con imagen y material.

## 5. Diagnóstico

En SQL Editor, con una sesión/rol de dirección desde la app ya configurado, ejecutar:

```sql
select public.app_diagnostico_final('11111111-1111-4111-8111-111111111111');
```

## 6. Siguiente fase

Tras validar producción: Firebase/FCM, Cron de avisos, APK release firmado y QR estable.
