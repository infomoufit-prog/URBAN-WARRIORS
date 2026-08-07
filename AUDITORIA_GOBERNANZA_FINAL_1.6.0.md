# Auditoría de gobernanza de guardado — Urban Warriors 1.6.0

## Problema raíz localizado

La 1.5.2 podía pasar pruebas SQL y, sin embargo, fallar desde el navegador porque las pruebas llamaban las funciones dentro de PostgreSQL y el frontend escribía por otra ruta: PostgREST + un cliente HTTP propio. La capa web seguía dependiendo de numerosas RPC históricas sin versión y conservaba DML genérico directo. Además, el cliente trataba una clave `sb_publishable_*` como si pudiera ser un JWT en algunos flujos de autenticación/renovación, y el service worker seguía identificado como `v1.4.0-build8`, lo que permitía mezclar runtime antiguo y nuevo.

## Correcciones de arquitectura

1. **Una sola puerta de escritura**: `app_mutate_v160`.
2. **Contrato obligatorio**: `app_runtime_contract_v160`; la web no habilita una mutación si backend/web no coinciden en `1.6.0`.
3. **Idempotencia** por UUID de petición: un reintento no duplica registros.
4. **Cierre de rutas antiguas**: se revoca DML directo en tablas funcionales para `anon/authenticated` y ejecución cliente de las RPC históricas de mutación.
5. **Auth correcta**: `sb_publishable_*` se usa exclusivamente como `apikey`; `Authorization` solo recibe el `access_token` real del usuario.
6. **Storage separado**: las cargas binarias mantienen sus policies; si el registro posterior falla, la app realiza borrado compensatorio donde corresponde.
7. **Caché saneada**: runtime `1.6.0-build11`, URLs con cache bust y service worker limitado al mismo origen; nunca intercepta Supabase/Firebase.
8. **Notificaciones transaccionales**: publicaciones y pagos no dependen de un segundo INSERT del navegador.
9. **Build gobernado**: Netlify no puede publicar si falla el preflight.
10. **Paridad web/APK**: el build compara SHA-256 de todos los assets web, dist y Android.

## Operaciones gobernadas

37 operaciones del frontend están registradas explícitamente en la puerta v1.6.0: cuentas, invitaciones, perfil, disciplinas, grados, grupos, alumnos, preinscripciones, matrículas, graduaciones, tarifas, material, publicaciones, sesiones, asistencia, check-in, seguimiento, documentos, notificaciones, pagos, cuotas, avisos, configuración y push.

## Verificaciones locales realizadas

- sintaxis de `data-store.js`, `app.js` y service worker;
- 28 controles de gobernanza del runtime;
- compatibilidad de la migración 015 contra las 13 migraciones previas presentes, 35 firmas legacy y 32 tablas;
- simulación navegador → PostgREST que verifica `apikey` publishable + JWT real + `app_mutate_v160`;
- rechazo automático de backend con versión incompatible antes de escribir;
- suites funcionales previas de estructura y recordatorios;
- preflight de producción;
- build determinista y paridad de 23 assets web/dist/Android.

## Verificación incorporada a la migración

La migración 015 no se limita a crear funciones: ejecuta un smoke test transaccional real a través de `app_mutate_v160`, comprueba idempotencia, confirma la escritura temporal y la elimina. Después verifica permisos: la puerta nueva debe estar expuesta y las rutas antiguas/DML directos deben estar cerrados. Cualquier fallo lanza una excepción y revierte la migración.

## Límite honesto de certificación

Desde este entorno no se puede ejecutar la migración dentro del proyecto Supabase del club ni publicar el deploy de Netlify. Por eso la certificación de producción solo puede cerrarse después de que `015_mutation_governance_v160.sql` termine con `Success` y el build gobernado de Netlify figure como `Published`. La arquitectura está diseñada para que un desfase web/backend produzca un error explícito y bloquee el guardado, en vez de aparentar éxito.
