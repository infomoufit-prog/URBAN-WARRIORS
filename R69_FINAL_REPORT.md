# KOMBAX R69 · Informe final

## Identidad

- Release: **R69 · EVENTS OPERATIONS CENTER READY**
- Build: **20120**
- Web: `2.0.0-rc.13-r69-events-operations-center`
- Android `versionCode`: **20120**

## Resultado funcional

KOMBAX Events queda dividido en dos espacios:

1. **Gestionar evento**: construcción, cartel, Fight Card, multimedia, visibilidad y publicación.
2. **Centro del evento**: operación, rendimiento, Ticketing, ventas, asistentes, QR, finanzas y devoluciones.

Se añade además **Mis Eventos**, un centro privado para listar todos los eventos que el usuario puede gestionar, incluidos borradores y privados.

### Sin Ticketing

El organizador conserva:

- Centro del evento.
- estadísticas básicas;
- edición/constructor;
- publicación;
- promoción;
- configuración.

Las herramientas dependientes de entradas aparecen visibles y explicadas, pero bloqueadas.

### Con Ticketing

Al estar activo/configurado se habilita la capa operativa de ventas y accesos. El Centro diferencia el estado de:

- servicio Ticketing;
- configuración;
- contratos/condiciones;
- Stripe Connect.

No se confunde publicación con Ticketing ni Ticketing con checkout preparado.

## Backend

Nueva migración live:

`20260914083811_kombax_r69_event_center_operations`

Nueva RPC privada:

`app_kombax_event_center_list_r69`

La función requiere autenticación y permiso efectivo de gestión por evento. `anon` no tiene permiso de ejecución.

Supabase health live: **versión 28 / build 20120**.

## Pruebas

Baterías release-specific:

- R69 Release Regression: **22/22**.
- R69 Commercial Continuity: **18/18**.
- R69 Identity + Spectator: **15/15**.
- R69 Showcase Seller Center Continuity: **13/13**.
- R69 Events Operations Center: **15/15**.

**Total: 83/83.**

`npm test`: exit 0.  
`npm run build`: exit 0.  
Build: **OK 206 archivos · web = dist = Android**.

## Android

Preflight: **4/5**.

Correcto:

- applicationId estable;
- versionCode 20120;
- web embebida;
- Firebase.

Pendiente:

- `android/keystore.properties` local.

Se intentó `assembleDebug`; el wrapper intentó descargar Gradle 8.11.1 y el entorno falló con `UnknownHostException: services.gradle.org`. No se generó APK/AAB y no se considera demostrada la compilación Android final.

## Cambios excluidos deliberadamente

R69 no modifica:

- precios R64.4;
- planes de KOMBAX;
- modelo Stripe Connect/direct charges;
- Seller Center R68;
- límites de Showcase;
- KOMBAX SaaS Billing;
- frontend live/Netlify;
- GitHub;
- Google Play.

## Estado de release

**QA READY para estabilización en Work y piloto controlado.**

No se etiqueta como production-ready público hasta cerrar QA manual autenticada, prueba Stripe E2E, firma Android, revisión legal/hardening y autorización de despliegue.
