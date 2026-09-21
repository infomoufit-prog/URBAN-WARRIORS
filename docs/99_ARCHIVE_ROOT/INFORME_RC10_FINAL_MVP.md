# Informe funcional · Urban Warriors 2.0.0-rc.10 · FINAL MVP

RC10 reúne las últimas mejoras solicitadas antes del congelado funcional del MVP.

## Experiencia de usuario

### Comunidad
La aplicación incorpora un espacio social interno y temporal separado de las comunicaciones oficiales. Un alumno/familia dispone de 3 publicaciones mensuales y el equipo del club de 5. Cada entrada contiene texto y una imagen o vídeo de hasta 15 segundos. La interfaz muestra la cuota consumida y la fecha de caducidad.

### Perfil
Cada cuenta puede tener una fotografía de perfil. La foto no crea una ficha pública: otros usuarios solo ven nombre y avatar cuando el autor participa en Comunidad. Al sustituirla se limpia el archivo anterior.

### Sesiones
Las clases pueden definirse como series semanales. El sistema mantiene ocurrencias futuras y permite excepciones de una sola fecha sin romper la recurrencia: cancelar, cambiar monitor, hora o sala. La reserva previa del alumno continúa separada del check-in real.

### Notificaciones
La bandeja deja de tratar cada evento como una tarea independiente. Agrupa por finalidad y permite leer un grupo o todo. Se separa el trabajo que requiere acción de los avisos informativos y se añaden preferencias push por categoría.

### Finanzas
Tesorería dispone de estado de cuenta y métricas operativas. Familia/Alumno puede consultar su propio histórico de cuotas, pagos validados, saldo y recibos, respetando los permisos existentes.

### Documentos, ayuda y formación
El archivo documental privado se mantiene. Los manuales se actualizan y quedan accesibles desde Ayuda. El cartel de descarga no se muestra al usuario ordinario y queda reservado al equipo autorizado.

### Legal
Registro y perfil exponen Condiciones de uso, Política de privacidad, Política de Comunidad y autorización de imagen. Las aceptaciones se versionan y la autorización de imagen puede retirarse para usos futuros.

## Automatizaciones de servidor

`notification-dispatch` realiza tres trabajos cuando se ejecuta de forma programada:
1. mantiene el horizonte de sesiones recurrentes;
2. publica/gestiona comunicaciones programadas y notificaciones;
3. purga contenido de Comunidad caducado, incluido su archivo de `community-media`.

`payment-reminders` se limita al circuito financiero y evita despachar categorías ajenas a cobros.

## Push: estado real

La aplicación queda **preparada a nivel de código**, pero no puede considerarse push de producción certificado solo con este ZIP. Para la certificación faltan elementos externos al repositorio:
- credencial Firebase de servidor como secreto de Supabase;
- secreto de invocación programada;
- Edge Functions desplegadas y llamadas periódicamente;
- `google-services.json` real dentro del proyecto Android;
- prueba física con la aplicación cerrada.

No se incluye ninguna credencial privada en el paquete GitHub.

## Alcance congelable

Superadas las pruebas reales, RC10 debe convertirse en la referencia del MVP. Nuevas funciones no críticas deberían posponerse a 2.1 para evitar reabrir el ciclo de certificación antes de publicación.
