# KOMBAX · RC13 build 20028 · Informe de implementación

Fecha: 2026-08-17
Base exclusiva: `KOMBAX_Urban_Warriors_RC13_build_20027_IMPLEMENTED_SQL_PATCHED(1).zip`

## 1. Objetivo

Build 20028 corrige la arquitectura de identidad pública y completa la experiencia KOMBAX descubierta durante la QA local del 20027. Urban Warriors continúa como primer Club real; KOMBAX es la capa global.

Principio estructural aplicado:

`Cuenta ≠ Miembro del Club ≠ Perfil deportivo ≠ Identidad Social de miembro ≠ Competidor KOMBAX ≠ Club ≠ Marca ≠ Federación ≠ Profesional ≠ Administrador global`.

No se han reescrito las migraciones 037–050 ya aplicadas en el proyecto remoto. La evolución de backend empieza en 051.

## 2. Implementado

### Identidad y KOMBAX Social
- Un miembro Social se mantiene como `Miembro`; un perfil deportivo ya no se interpreta como `Competidor`.
- Competidor/Marca/Federación/Profesional siguen siendo perfiles KOMBAX directos y verificados.
- Selector `ACTUAR COMO` cuando una cuenta dispone de varias identidades.
- Gestor/Coordinación usa por defecto la identidad pública del Club dentro del contexto del Club.
- Permisos explícitos para que equipo autorizado actúe como Club.
- Auditoría separa `actor real` de `identidad pública`.
- Activación Social de miembro mantiene edad y consentimiento como gates.
- Perfil Social de miembro ahora permite editar bio, avatar y portada públicos sin copiar automáticamente datos administrativos.

### Perfiles públicos
- Tarjetas, nombres y autores de Social abren una ficha pública completa.
- Ficha con avatar, banner, información permitida, álbum, actividad, relaciones y Showcase cuando corresponde.
- Club y perfil personal permanecen separados.
- Resolución de tipo de perfil centralizada.
- Backfill de logo/portada del Club protege el branding más reciente frente a copias públicas antiguas.

### Hub del Club
- `Mi perfil` para Gestor/Coordinación abre el Hub KOMBAX del Club.
- Gestión de perfil público, álbum, Social, Showcase, relaciones, contactos y permisos.
- `Ver como público`.
- Separación visible entre presencia pública e información interna.

### Multimedia Social
- `+ Publicar` permite subir foto/vídeo directamente o elegir del álbum.
- Vídeo limitado a 15 s desde backend.
- Álbum Social de miembro: 10 fotos + 3 vídeos.
- Avatar y banner separados del álbum.
- Reutilización de álbum del Club y perfil KOMBAX directo.
- Limpieza best-effort de avatar/portada anterior cuando el objeto pertenece al mismo actor.

### Showcase
- CTA configurables: información, contacto, tienda/web y dónde encontrar.
- Guardar y compartir.
- Gestión por Club/Marca según permisos.
- Se mantienen límites 15 Club / 30 Marca.
- No se introduce carrito, checkout, pago KOMBAX, pedido, logística ni stock transaccional.

### Administración global KOMBAX
- Rol backend `platform_admin`, separado del Gestor de Club.
- No existe autorización por email hardcodeado en frontend.
- La misma cuenta puede conservar su rol en Urban Warriors y recibir además llave global por UUID.
- Consola global con Clubes, cuentas/perfiles, verificaciones, moderación, relaciones/contactos, auditoría y estado técnico reservado.
- Acceso a Club desde consola sin suplantación silenciosa.
- `platform_admin` hereda capacidad de moderación/verificación desde backend.

### Limpieza de producto
- Eliminado el badge visible `SaaS multiclub · Contact sports`.
- Eliminados/restringidos mensajes técnicos de las superficies normales.
- Diagnóstico/certificación técnica queda reservado a Administración KOMBAX.
- Mensajes de Social dependen ahora del contexto real, no de la antigua regla “solo alumno”.

## 3. Backend nuevo

| Ciclo | Función |
|---|---|
| 051 | Identidad Social separada, permisos de equipo, actuar como Club, auditoría |
| 052 | Directorio y perfil público completo |
| 053 | Multimedia directa Social, avatar/banner/álbum, feed 20028 |
| 054 | Showcase accionable y guardados |
| 055 | Administrador global KOMBAX y consola backend |
| 056 | Contrato técnico de release reservado a platform_admin |

Cada ciclo contiene `preflight`, migración, `verify`, prueba transaccional y rollback.

## 4. Archivos frontend principales

Nuevos:
- `web/js/core/identity-context.js`
- `web/js/modules/public-profile.js`
- `web/js/modules/club-kombax-hub.js`
- `web/js/modules/platform-admin.js`

Revisados de forma sustancial:
- `web/js/modules/kombax-social.js`
- `web/js/modules/showcase.js`
- `web/js/modules/admin.js`
- `web/js/app.js`
- `web/js/core/repositories.js`
- `web/js/core/backend.js`
- `web/js/modules/gateway.js`
- `web/css/kombax-premium.css`

## 5. Validación local realizada

- `npm test`: PASS tras la implementación final.
- `npm run build`: PASS.
- Build reporta: `70 archivos · web = dist = Android`.
- Sintaxis de todos los módulos JS (`node --check`): PASS.
- Auditoría estática 051–056: transacciones, `$$` equilibrados y ausencia del conflicto reservado `position`: PASS mediante suite 20028.
- Smoke HTTP local: `http://127.0.0.1:4173` responde y carga assets `?v=20028`.
- Android:
  - `applicationId`: `com.urbanwarriors.app`.
  - `versionCode`: `20028`.
  - assets Android presentes.
  - preflight: 3/5.
  - pendientes externos intencionales: `google-services.json` real y `android/keystore.properties` / JKS local.

## 6. Lo que NO está certificado todavía

Las migraciones 051–056 **no se han aplicado ni verificado todavía contra el Supabase remoto**. Por tanto:
- el backend remoto actual certificado manualmente por el usuario llega hasta 050;
- 051–056 deben ejecutarse siguiendo el runbook del 20028;
- después deben realizarse tests transaccionales/E2E con cuentas reales, aislamiento entre dos clubes y Storage;
- no se declara Google Play production-ready todavía.

## 7. Estado correcto

**Build 20028 implementado y validado estáticamente/localmente, preparado para la fase de actualización de Supabase y QA local funcional.**
