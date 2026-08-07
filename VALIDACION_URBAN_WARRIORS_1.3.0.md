# Validación Urban Warriors 1.3.0

Fecha: 6 de agosto de 2026.

## Comprobado automáticamente

- Sintaxis de `config.js`, aplicación, data store, push y service workers.
- Ausencia de datos demo cuando el modo de producción está activo.
- Inicialización segura de todas las colecciones.
- Renovación automática de JWT.
- Llamadas RPC para disciplinas, grados, grupos y horarios.
- Altas y cambios de alumnos.
- Tarifas, material, publicaciones, sesiones y graduaciones.
- Aprobación y rechazo de preinscripciones.
- Invitaciones de personal.
- Solicitud y actualización de pedidos de material.
- Upload público de imágenes y upload privado de documentos.
- Cinco avisos configurables, agrupación familiar, idempotencia, justificantes y pausas.
- Build web/PWA y copia a los assets del proyecto Android.

Comandos ejecutados:

```bash
npm test
npm run build
```

Resultado: correcto.

## Implementado, pendiente de validación en el Supabase real

- Ejecución de la migración 007.
- Escrituras reales de todos los perfiles bajo RLS.
- URLs firmadas de documentos en el proyecto activo.
- Flujo completo desde dos navegadores y varios roles.
- Cron y Edge Functions desplegadas.
- Envío real de FCM.
- Compilación y firma del APK release.

## Estado del producto

La versión es una candidata operativa de producción. No debe introducirse información sensible definitiva hasta completar la prueba manual por roles en el Supabase real.
