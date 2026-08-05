# Urban Warriors · App 1.2

Aplicación móvil/PWA personalizada para **Urban Warriors**, con gestión de alumnos, familias, clases, asistencia, cuotas, pagos, material, publicaciones y notificaciones. La base utiliza `club_id` para poder evolucionar a una SaaS multi-club.

## Incluido en esta entrega

- Registro general con dos flujos: alumno adulto y padre/madre/tutor.
- Menores vinculados a la cuenta adulta; no crean una cuenta independiente.
- Perfiles de dirección, secretaría, tesorería/economía, comunicación, monitor, familia y alumno.
- Preinscripciones, aprobación, socios, disciplinas, grados, grupos y horarios.
- Sesiones, código de acceso, check-in y pase de asistencia.
- Seguimiento deportivo y graduaciones preparadas en el esquema.
- Tarifas, generación de cuotas, cobros manuales y pagos parciales.
- Comunicación de pago por el usuario y justificante privado.
- Validación o rechazo por dirección, secretaría o tesorería.
- Pausa y reactivación manual de alarmas de una cuota.
- **Cinco avisos automáticos configurables**; valores iniciales: días 1, 4, 8, 11 y 14.
- Detención de avisos cuando la cuota está pagada, anulada, exenta, aplazada, pausada o pendiente de validación.
- Agrupación de varios menores de una misma familia en una sola notificación.
- Historial idempotente de avisos y cambio a vencida desde el día 15.
- Posts, carteles, imágenes, noticias, eventos y clases especiales.
- Material, variantes/tallas, stock, solicitudes y entrega.
- Centro de notificaciones, PWA, proyecto Android y página de descarga.
- Edge Function para ejecutar recordatorios y enviar push mediante Firebase cuando se aporten credenciales.
- Manual y cartel del gimnasio en `docs/`.

## Modo de demostración

```bash
npm run dev
```

Abre `http://localhost:4173`.

Usuarios:

- `admin@urbanwarriors.demo`
- `monitor@urbanwarriors.demo`
- `familia@urbanwarriors.demo`

Contraseña: `demo1234`.

Los datos de demostración se guardan en `localStorage`.

## Validación y build

```bash
npm test
npm run build
```

El build se genera en `dist/` y se copia también a `android/app/src/main/assets/www/`.

## Activar Supabase

Ejecuta, en orden:

1. `supabase/migrations/001_phase1_complete.sql`
2. `supabase/migrations/002_access_payments_posts_notifications.sql`
3. `supabase/migrations/003_extend_fee_status.sql`
4. `supabase/migrations/004_payment_reminders_workflow.sql`

Después modifica `web/config.js`:

```js
window.UW_CONFIG = {
  demoMode: false,
  supabase: {
    enabled: true,
    url: 'https://TU-PROYECTO.supabase.co',
    anonKey: 'TU_ANON_KEY_PUBLICA'
  }
};
```

La clave `service_role` nunca debe incluirse en la web ni en el APK.

## Distribución prevista

- **Web/PWA y página estable del QR:** Netlify.
- **Backend, Auth, base de datos, archivos y tareas:** Supabase.
- **APK versionado:** GitHub Releases o un bucket público de versiones.
- **QR impreso:** apunta a la página estable `/#/download`, no al APK directamente.

Consulta `DEPLOYMENT.md`, `ANDROID.md` y `PENDIENTES.md`.
