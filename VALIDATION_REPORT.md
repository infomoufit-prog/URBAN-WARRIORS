# Informe de validación · 2026-08-05 · versión 1.2.0

## Comprobado correctamente

- Sintaxis de `config.js`, app, data store, push y service workers mediante `node --check`.
- Build web y copia de assets al proyecto Android.
- Presencia de migraciones `001` a `004` y Edge Function.
- Registro de adulto/tutor, menor vinculado y preinscripción.
- Cuotas y registro de cobros.
- Comunicación de pago y justificante.
- Validación y rechazo.
- Pausa, reactivación y caducidad de la pausa.
- Agrupación de dos mensualidades familiares.
- Idempotencia: una fecha no repite el mismo aviso.
- Exclusión de una cuota pendiente de validación de avisos posteriores.
- Cinco días configurables y vencimiento desde el día 15.
- Posts, eventos, material, check-in y asistencia.

## Comandos ejecutados

```bash
npm test
npm run build
```

Resultado: correcto.

## Implementado pero no ejecutado contra servicios externos

- SQL PostgreSQL/Supabase real y RLS.
- Storage privado y URL firmada.
- Edge Function desplegada.
- Supabase Cron.
- Firebase Cloud Messaging.
- Compilación Android con SDK/Gradle.

Estas comprobaciones requieren credenciales e infraestructura del propietario.

## Compilación Android en este entorno

Se intentó `npm run android:debug`, pero el contenedor no dispone del ejecutable Gradle/Android SDK (`gradle: not found`). El repositorio incluye workflows de GitHub Actions para realizar la compilación en un entorno Android configurado.
