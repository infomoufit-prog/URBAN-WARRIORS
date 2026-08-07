# Actualización Urban Warriors 1.3.0

Esta versión sustituye los parches parciales anteriores y convierte los formularios principales en operaciones reales contra Supabase.

## Orden exacto de instalación

### 1. Copia de seguridad

En Supabase abre **Database → Backups** y comprueba que existe una copia reciente. Durante las pruebas utiliza información ficticia.

### 2. Ejecutar la migración 007

1. Abre `supabase/migrations/007_operational_v130.sql`.
2. Copia todo el contenido.
3. En Supabase entra en **SQL Editor → New query**.
4. Pega el código y pulsa **Run** una sola vez.
5. El resultado esperado es `Success. No rows returned`.

La migración crea:

- operaciones transaccionales para todos los formularios principales;
- invitaciones de personal;
- documentos privados de alumnos;
- creación y edición de grupos con horarios;
- aprobación/rechazo de preinscripciones;
- publicaciones y notificaciones del servidor;
- pedidos de material y avisos;
- vista de progreso del alumno;
- preparación de publicaciones programadas.

### 3. Actualizar GitHub

1. Descomprime `urban-warriors-v1.3.0-parche-github.zip`.
2. En GitHub abre `URBAN-WARRIORS`.
3. Pulsa **Add file → Upload files**.
4. Arrastra todo el contenido interior del parche, incluidas sus carpetas.
5. Confirma que aparecen rutas como `web/js/app.js`, `web/js/data-store.js` y `supabase/migrations/007_operational_v130.sql`.
6. Pulsa **Commit changes** en `main`.

### 4. Esperar a Netlify

En Netlify abre `urban01 → Deploys`. Espera hasta que el despliegue figure como **Published**.

### 5. Limpiar la versión anterior

Abre `https://urban01.netlify.app` en incógnito o pulsa `Ctrl + F5`. Si persiste una versión antigua, elimina los datos del sitio y vuelve a iniciar sesión.

## Prueba operativa obligatoria

Realiza estas acciones en orden, con datos ficticios:

1. Crear y editar una disciplina.
2. Crear un grado.
3. Crear un grupo con uno o varios horarios y editarlo.
4. Crear una sesión de entrenamiento.
5. Crear un alumno y asignarle disciplina, grupo, grado y tarifa.
6. Registrar seguimiento y graduación.
7. Crear una preinscripción, aprobarla y rechazar otra.
8. Crear y editar una tarifa; generar mensualidades.
9. Registrar un cobro y comunicar otro con justificante.
10. Pausar y reactivar los cinco avisos.
11. Publicar una noticia y un evento con imagen.
12. Crear material con imagen, variantes y stock.
13. Solicitar material como usuario y cambiarlo a preparado/entregado como administración.
14. Subir un documento al perfil del alumno.
15. Comprobar que todos los cambios continúan después de recargar y desde otro navegador.

## Firebase y alertas externas

La aplicación ya contiene:

- registro de tokens web/Android en `dispositivos_push`;
- Edge Function `payment-reminders`;
- Edge Function `notification-dispatch` para cualquier aviso interno;
- soporte FCM web y Android;
- publicación automática de comunicaciones programadas.

Para activarlo más adelante hay que crear Firebase, añadir la configuración pública en `web/config.js`, guardar `FIREBASE_SERVICE_ACCOUNT_JSON` en Supabase, desplegar ambas funciones y programar los dos Cron de ejemplo.

## Regla de seguridad

No compartas la contraseña de la base, la clave `service_role`, el JSON de Firebase ni el keystore de Android. La clave `publishable` del navegador no sustituye las políticas RLS.
