# KOMBAX R118 · build 20177 · Pilot Stabilization Validation

Fecha de validación: 2026-10-03  
Release: `2.0.0-rc.13-r118-pilot-stabilization-1`  
Android versionCode: `20177`  
Paquete Android: `com.urbanwarriors.app`

## Alcance certificado

R118 estabiliza la arquitectura de identidad y el onboarding del piloto sin sustituir los datos históricos:

- una cuenta Auth por email y un Perfil Social personal canónico;
- facetas personales compatibles (Miembro/Practicante, Competidor, Profesional);
- roles internos de Club separados de las facetas personales;
- `kombax_account_types_r100` conservado solo como metadato legado de onboarding;
- alta directa y progresiva de Club Piloto, sin código/documentación/disciplinas obligatorias;
- continuidad de alta piloto entre pestañas durante la confirmación del email;
- credenciales profesionales con evidencia privada, declaración versionada, revisión individual y publicación selectiva;
- Discovery agrupado por persona para evitar tarjetas duplicadas Competidor/Profesional;
- invitaciones generales y nominativas de alumnos/familias y equipo preservadas;
- tareas de notificación ligadas al estado real de la solicitud;
- avisos explícitos de aprobación/rechazo al solicitante;
- prevención de reapertura de solicitudes de miembro ya satisfechas;
- endurecimiento del gateway de ciclo de vida de notificaciones.

## Punto de restauración

La rama `pilot-20176-before-r118` conserva el estado anterior a R118:

`16a1449477ae12ee0d8587d4235d77a757db341d`

R118 se implementó en `r118-identity-pilot`. Todas las migraciones que cambian contratos tienen archivos de rollback en `supabase/rollback`.

## Supabase live

Proyecto validado: `poggsobhtutbuagjiydc`.

Migraciones R118 confirmadas live:

1. `kombax_r118_multifacet_identity_core`
2. `kombax_r118_professional_credentials`
3. `kombax_r118_canonical_person_discovery`
4. `kombax_r118_discovery_contact_limit`
5. `kombax_r118_request_outcome_notifications`
6. `kombax_r118_notification_lifecycle_gateway`
7. `kombax_r118_already_linked_request_guard`
8. `kombax_r118_resolved_link_notification_cleanup`

Nota de orden live: el gateway de ciclo de vida se aplicó antes que el guard de solicitud ya satisfecha al detectarse una incompatibilidad histórica. Los archivos numerados quedaron corregidos para una instalación secuencial limpia.

## Invariantes live finales

Consulta de producción, sin crear datos sintéticos:

- propietarios con más de una identidad social canónica: **0**
- facetas personales duplicadas por tipo: **0**
- enlaces canónicos cruzados entre propietarios: **0**
- solicitudes de equipo pendientes con acceso de equipo ya activo: **0**
- solicitudes de miembro abiertas ya satisfechas por membresía real: **0**
- claims pendientes con acceso ya activo: **0**
- credenciales con estado inglés legado `verified`: **0**
- credenciales públicas no verificadas/caducadas: **0**
- avisos accionables de equipo obsoletos: **0**
- avisos accionables de vinculación obsoletos: **0**

Capacidad del piloto en la validación: **1 Club utilizado de 4 plazas configuradas**.

## Incidencia descubierta y corregida durante QA

Al intentar reparar una solicitud histórica ya satisfecha, Supabase rechazó la transición con `LIFECYCLE_GATEWAY_REQUIRED`. La causa no era R118: los triggers R117 archivaban notificaciones por UPDATE directo mientras `app_guard_ciclo_v038` exigía el gateway de ciclo de vida.

Se corrigió antes del release:

- los triggers de equipo, club-link y membership-claim activan/restauran el gateway solo durante el archivado;
- la solicitud real obsoleta quedó resuelta;
- los avisos de gestor heredados del hilo quedaron archivados;
- el aviso de resultado al usuario se conserva;
- no se borró historial.

Los intentos de migración que fallaron fueron transaccionales y no quedaron aplicados parcialmente.

## QA del código almacenado en GitHub

Validaciones realizadas contra la rama R118:

- release/versionado: **8/8**
- ciclo de solicitudes/notificaciones: **8/8**
- invariantes Supabase: **PASS**
- advisors de seguridad específicos de tablas/RPC R118: **sin hallazgos nuevos**
- advisors de rendimiento específicos de credenciales R118: **sin hallazgos nuevos**

Los bloques de identidad/piloto y credenciales/Discovery detectaron inicialmente tres falsos negativos del propio script de QA por expresiones demasiado rígidas. Se inspeccionó el código objetivo y se corrigieron las aserciones del gate:
- desbloqueo del alta piloto por `account_type`;
- estado pendiente de solicitud de equipo;
- etiqueta real del documento de evidencia profesional.

## Paridad de frontend

Blob SHA idéntico en `web`, `dist` y assets Android:

- `js/core/account-profile-policy.js` — `21d8accb8432310d369a2ae491fc87b157367994`
- `js/core/repositories.js` — `90ef3c9345b55050883de0a3bfd1f517aa64ef46`
- `js/modules/gateway.js` — `e91b6ce891be531a1c485901b1af96db6558c1b0`
- `js/modules/kombax-discovery.js` — `612328c41a7bb575a564f4d852ab37194b12fb58`
- `js/modules/platform-admin.js` — `41d4d9cc8dbe88f077690f6cbd6165fcebb7029d`
- `js/modules/professional-operations.js` — `1fa23ed7f66f36a220479c913019e5e65178b7cd`
- `js/modules/public-profile.js` — `d2aa3c20b670322161dc8b711d4d351b62454d9a`
- `config.js` — `f68bd857a7be13b7c6a7a7e053fa55d758c51d8b`

## Límites de la evidencia

No se declara como ejecutado lo que no pudo ejecutarse:

- el entorno de trabajo no pudo clonar GitHub por fallo DNS (`Could not resolve host: github.com`);
- el repositorio no contiene GitHub Actions para ejecutar el gate Node en CI;
- por ello, el script `test-kombax-20177-r118-pilot-stabilization.mjs` está versionado y sus aserciones fueron auditadas contra los blobs, pero no se declara una ejecución local completa de `npm run verify:20177`;
- no se ha compilado AAB/APK release firmada porque la firma pertenece al entorno local del propietario;
- no se ha subido nada a Google Play;
- no se han realizado cargos Stripe;
- no se han enviado emails reales como QA;
- el conector Netlify disponible no expone el sitio KOMBAX, por lo que no se declara deploy de `kombax.es` desde esta sesión.

## Comandos de release previstos

Validación local:

```
npm run test:20177:r118
npm run verify:20177
```

Android debug QA:

```
npm run android:debug:r118
```

Bundle para Play, solo en entorno autorizado con firma:

```
npm run android:play:r118
```

El despliegue Netlify debe hacerse únicamente sobre el sitio KOMBAX correcto. Nunca sobre `learninglabnexo`.
