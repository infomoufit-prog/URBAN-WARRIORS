# Arquitectura · Urban Warriors 2.0.0-rc.10

## Principio

RC10 amplía RC9 sin sustituir el canal estable de persistencia. El frontend mantiene una única ruta de mutación gobernada y separa claramente UI, repositorios, backend y cliente Supabase.

## Capas

1. `web/js/core/supabase.js`: Auth, PostgREST, RPC y Storage.
2. `web/js/core/backend.js`: sesión, contrato, mutación, diagnóstico, subida/descarga y sincronización de token push.
3. `web/js/core/repositories.js`: acceso por dominio y limpieza física de archivos.
4. `web/js/core/state.js`: estado UI mínimo.
5. `web/js/modules/*` + `web/js/ui/*`: experiencia por rol.

## Escritura

`UI → repository → backend.mutate() → app_mutate_v160 → respuesta verificada → lectura → render`

No se incorpora un store monolítico alternativo ni DML directo desde los módulos.

## Contrato

- Backend: `1.6.0`
- Schema epoch: `160`
- Gateway: `app_mutate_v160`
- RC9 queda encapsulado por el wrapper de RC10.
- Migración nueva: `022_rc10_final_mvp_v166.sql`.

## Dominios añadidos en RC10

### Notificaciones
Lectura individual, por grupo y total; preferencias push por categoría; visualización agrupada y distinción de acciones pendientes.

### Sesiones recurrentes
`series_sesiones` define recurrencias semanales. Las ocurrencias concretas siguen viviendo en `sesiones_entrenamiento`, lo que permite reservas, asistencia e histórico por fecha. Las excepciones se aplican a una ocurrencia sin destruir la serie.

### Comunidad
`publicaciones_comunidad` es independiente de las comunicaciones oficiales. Los archivos viven en `community-media` privado y la UI obtiene URLs firmadas. El mantenimiento programado purga contenido caducado y media asociada.

### Perfil
`perfiles.avatar_path` referencia un objeto privado de `profile-media`. Sustitución y borrado limpian el objeto anterior.

### Finanzas
`v_estado_cuenta_socio` presenta cuota, pagos validados, saldo, estado y recibo sin crear una segunda contabilidad paralela.

### Legal
`textos_legales` conserva documentos versionados y `aceptaciones_legales` registra decisiones del usuario. La autorización de imagen permanece separada de las condiciones necesarias para acceder al servicio.

## Storage

- `member-documents`: expediente privado.
- `justificantes-pago`: justificantes privados.
- `club-public-media`: publicaciones oficiales, material y branding.
- `profile-media`: avatares privados.
- `community-media`: contenido social temporal privado.

## Push y tareas programadas

- `notification-dispatch`: horizonte recurrente, publicaciones/notificaciones programadas, limpieza de Comunidad y push general/sesiones/comunidad.
- `payment-reminders`: recordatorios financieros y push financiero.

Ambas funciones requieren configuración externa de producción; las credenciales no forman parte del repositorio.

## Android

- `versionName 2.0.0-rc.10`
- `versionCode 20010`
- Firebase Messaging integrado condicionalmente cuando existe `google-services.json` real.
- Una push abierta desde Android conserva la ruta funcional hacia la app.
- `web`, `dist` y `android/app/src/main/assets/www` se sincronizan mediante `npm run build`.
