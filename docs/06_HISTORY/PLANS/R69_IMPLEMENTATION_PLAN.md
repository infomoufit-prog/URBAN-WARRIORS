# KOMBAX R69 · Plan de implementación ejecutado

**Build:** 20120  
**Objetivo:** separar definitivamente la construcción visual de un evento de su gestión operativa y comercial.

## 1. Arquitectura de producto

Se conserva **Gestionar evento** como editor/constructor: datos, cartel, banner, Fight Card, participantes, multimedia, visibilidad y publicación.

Se incorpora **Mis Eventos** como centro permanente del organizador y **Centro del evento** como dashboard operativo de cada evento.

Principio funcional:

- Publicar un evento no activa Ticketing.
- Ticketing se activa por evento.
- Un evento sin Ticketing mantiene métricas básicas y herramientas de edición/promoción.
- Las funciones dependientes de Ticketing permanecen visibles pero bloqueadas con explicación.
- Cuando Ticketing está operativo se habilitan ventas, entradas, asistentes, QR/check-in, finanzas, comunicaciones, reembolsos e histórico de acceso.
- Business Intelligence sigue siendo una capacidad Enterprise separada.

## 2. Backend privado de Mis Eventos

Se añadió la RPC `app_kombax_event_center_list_r69` para devolver eventos que el usuario autenticado puede gestionar, incluidos borradores, privados y no publicados.

La RPC:

- exige sesión autenticada;
- valida cada evento con `app_kombax_evento_puede_gestionar_v160`;
- no se concede a `anon` ni `public`;
- se concede únicamente a `authenticated`;
- agrega estado de publicación, Ticketing, capacidad, entradas pagadas/reservadas/usadas/reembolsadas, ingresos y analítica operativa de 30 días.

## 3. Interfaz Mis Eventos

Se añadió acceso visible **Mis Eventos** para contextos autorizados a organizar.

El listado muestra por evento:

- estado del evento;
- fecha y ubicación;
- estado de Ticketing;
- vistas 30 días;
- entradas pagadas;
- check-ins;
- ocupación o ingresos;
- acceso diferenciado a **Centro del evento**, **Gestionar evento** y ficha pública.

## 4. Centro del evento

Se incorporó un dashboard operativo con:

- Resumen / KPIs.
- Estadísticas básicas.
- Activación y gestión de Ticketing.
- Entradas y ventas.
- Asistentes.
- Control de acceso QR.
- Finanzas.
- Reembolsos / cancelaciones.
- Comunicaciones.
- Historial de accesos.
- Equipo de acceso.
- Promoción.
- Configuración.
- BI Enterprise.

El bloque de Ticketing hace visibles cuatro estados independientes: **Servicio, Configuración, Condiciones y Stripe**.

## 5. Continuidad comercial

No se modifican precios ni planes. Se conserva la base R64.4:

- Publicación Events: 7 d 5 €, 15 d 8 €, 30 d 12 €, 60 d 18 €.
- Destacar: 7 d 3 €, 15 d 5 €, 30 d 8 €.
- Ticketing: ≤50 10 €, ≤100 15 €, ≤200 25 €, ≤500 45 €, ≤1000 75 €, >1000 personalizado.
- Fee fija comprador: 0 €.
- Fee plataforma: 1,5 % no Enterprise / 0 % Enterprise.
- Enterprise mantiene Ticketing incluido.

R69 tampoco modifica Showcase R68 ni KOMBAX SaaS Billing.

## 6. Validación

Se añadieron tests específicos R69 y se repitieron regresión, continuidad comercial, identidad/Espectador y Seller Center.

Resultado release-specific: **83/83** comprobaciones superadas.

`npm run build` sincroniza **206 archivos** con resultado `web = dist = Android`.

Android preflight: **4/5**. Falta únicamente `android/keystore.properties` local.

El intento `assembleDebug` no pudo comenzar la compilación porque el entorno no resuelve `services.gradle.org`; no se declara APK/AAB generado.
