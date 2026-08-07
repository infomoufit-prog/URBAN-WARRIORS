# Urban Warriors 1.6.0

Aplicación web/PWA y proyecto Android para la gestión diaria de Urban Warriors. Web y APK comparten Supabase como fuente de verdad.

## Arquitectura de escritura 1.6.0

Desde 1.6.0 el navegador **no escribe directamente en tablas ni invoca RPC históricas**. Todas las mutaciones pasan por un único contrato versionado:

- contrato: `app_runtime_contract_v160`
- mutación: `app_mutate_v160`
- diagnóstico del canal: `app_write_channel_probe_v160`
- idempotencia: `app_mutation_requests.request_id`

La web bloquea cualquier guardado si su versión de backend no coincide con `1.6.0`. La migración 015 revoca DML directo para `anon/authenticated` y revoca la ejecución cliente de las RPC de mutación antiguas; esas funciones solo quedan encapsuladas en servidor.

## Módulos gobernados

- cuentas e invitaciones;
- perfil;
- disciplinas y grados;
- grupos y múltiples horarios;
- alumnos, multideporte y multigrupo;
- preinscripciones, lista de espera, aprobación y rechazo;
- matrículas y graduaciones;
- tarifas, cuotas, cobros, justificantes y cinco avisos;
- publicaciones/eventos;
- material, variantes, stock y pedidos;
- sesiones, check-in, asistencia y seguimiento;
- documentos y notificaciones;
- configuración del club y registro de dispositivos push.

## Control de deploy

`npm run build` ejecuta primero el preflight de gobernanza. Si detecta RPC antiguas en el runtime, DML directo, versión/cache incoherente, firmas SQL incompatibles o un canal HTTP mal formado, el build falla y Netlify no publica esa revisión.

```bash
npm test
npm run build
```

El build copia y verifica por SHA-256 que `web/`, `dist/` y los assets Android sean idénticos.

## Actualización desde 1.5.2

1. Ejecutar **una sola vez** `supabase/migrations/015_mutation_governance_v160.sql`.
2. La propia migración ejecuta un smoke test transaccional y revierte si la gobernanza no queda instalada correctamente.
3. Subir el parche 1.6.0 a GitHub.
4. Netlify ejecutará el preflight antes de publicar.

No volver a ejecutar migraciones anteriores que ya finalizaron correctamente.
