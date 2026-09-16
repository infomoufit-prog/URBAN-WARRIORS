# KOMBAX R77 · Premium Analytics, Reports & Events Results

**Build:** 20128  
**Base:** R76 / build 20127  
**Release tag:** `r77-premium-analytics-reports`  
**Fecha de cierre:** 2026-09-16  
**Estado:** **PILOT FREEZE CANDIDATE** · no desplegada en GitHub/Netlify/Google Play

## 1. Objetivo

R77 convierte **Mi Showcase** y **KOMBAX Events** en centros operativos con analítica premium, navegación estructurada e informes PDF privados, preservando la separación arquitectónica fijada en R75 entre **Explorar Showcase** y **Mi Showcase** y manteniendo la mejora visual Social Discovery de R76.

La release utiliza datos transaccionales reales existentes. No fabrica métricas: si una magnitud no está registrada, no se presenta como dato confirmado.

## 2. Mi Showcase

La navegación privada queda organizada en:

**Resumen → Productos → Pedidos → Stock → Estadísticas → Informes → Finanzas → Commerce → Configuración**

Cambios principales:

- dashboard ejecutivo con KPIs y comparación contra periodo anterior;
- selector temporal: 7 días, 30 días, mes actual, mes anterior, trimestre, año y rango personalizado;
- histogramas/series temporales, barras por categoría y tablas de rendimiento;
- analítica por producto con ventas, unidades, ingresos, vistas, interés y stock;
- tarjetas privadas de producto con miniatura 1:1, precio, categoría, stock, estado, rendimiento y acciones;
- catálogo público con imagen 1:1 también en escritorio;
- estados vacíos/errores y composición responsive específica.

### Separación pública/privada preservada

- **Explorar Showcase** continúa siendo el marketplace público global.
- **Mi Showcase** continúa resolviendo exclusivamente la entidad activa autorizada.
- El contexto privado no contamina el catálogo público.
- R77 no revierte ni sustituye la corrección multiclub R75.

## 3. Showcase Analytics

El backend agrega, cuando existen datos verificables:

- facturación bruta;
- pedidos;
- unidades vendidas;
- ticket medio;
- compradores y recurrencia;
- reembolsos;
- impresiones/vistas/interés;
- checkout y compras;
- conversión;
- stock, bajo stock y sin stock;
- rendimiento por producto y categoría.

Se utilizan RPC agregadas para evitar una cadena de múltiples llamadas secuenciales desde el navegador.

## 4. Events Analytics y Resultados

El Centro del evento incorpora:

**Resumen → Tickets → Estadísticas → Resultados → Informes**

La analítica puede mostrar, según datos existentes:

- entradas vendidas;
- ingresos;
- pedidos;
- ticket medio;
- compradores;
- aforo/ocupación;
- check-ins;
- reembolsos;
- participantes;
- combates y resultados.

La vista **Resultados** utiliza exclusivamente datos almacenados y puede distinguir:

- estelar / coestelar;
- peleador A / peleador B;
- ganador;
- método;
- asalto;
- tiempo;
- estado oficial/provisional cuando exista.

No se infieren resultados inexistentes.

## 5. KOMBAX Reports

R77 incorpora un motor común de informes, no dos generadores independientes.

Edge Function live:

`kombax-report-r77` · **v2** · JWT obligatorio.

Bucket:

`kombax-reports` · privado · solo PDF · límite 20 MB.

El motor soporta:

### Showcase

- informe general;
- ventas;
- finanzas;
- productos;
- stock;
- pedidos;
- rendimiento comercial.

### Events

- informe general;
- ventas;
- finanzas;
- tickets;
- asistencia/check-in;
- participantes;
- combates;
- resultados oficiales;
- ejecutivo.

Los documentos pueden incluir:

- logo del vendedor/organizador;
- cartel del evento cuando procede;
- periodo exacto;
- KPIs;
- histogramas;
- tablas;
- miniaturas 1:1 de productos;
- resultados deportivos confirmados;
- branding KOMBAX.

Los PDFs se guardan en Storage privado y se entregan mediante URL firmada temporal.

## 6. Privacidad de informes

Los payloads operativos de R77 evitan exportar PII innecesaria. Los informes de pedidos/tickets trabajan con identificadores operativos, estados, importes, cantidades y fechas, sin requerir correo, teléfono o dirección del comprador.

Las RPC de informes y analítica requieren sesión autenticada y autorización real sobre proveedor/evento; ocultar botones en frontend no es la barrera de seguridad.

## 7. Backend / Supabase

Migraciones R77 aplicadas:

- `kombax_analytics_reports_r77`
- `kombax_report_payload_completeness_r77`
- `kombax_analytics_exact_range_r77`
- `kombax_report_exact_range_r77`

Archivos locales:

- `265_kombax_analytics_reports_r77.sql`
- `266_kombax_report_payload_completeness_r77.sql`
- `267_kombax_analytics_exact_range_r77.sql`
- `268_kombax_report_exact_range_r77.sql`

RPC principales:

- `app_kombax_showcase_analytics_r77`
- `app_kombax_event_analytics_r77`
- `app_kombax_report_payload_r77`
- `app_kombax_showcase_analytics_range_r77`
- `app_kombax_event_analytics_range_r77`
- `app_kombax_report_payload_range_r77`

Verificación de las RPC de rango/reporting:

- `SECURITY DEFINER`: sí;
- `search_path`: cerrado;
- `anon EXECUTE`: no;
- `PUBLIC EXECUTE`: no;
- `authenticated EXECUTE`: sí;
- autorización de proveedor/evento comprobada dentro de función.

R77 no crea tablas públicas nuevas.

## 8. Responsive y producto 1:1

Se añadió `kombax-analytics-r77.css` y componentes UI reutilizables. La composición cubre escritorio, portátil, tablet, móvil vertical/horizontal, PWA y Android WebView.

Las imágenes principales de producto utilizan contenedor cuadrado 1:1 sin deformación y con fallback, tanto en catálogo público como en gestión privada y reporting compatible.

## 9. i18n

Idiomas activos:

ES · EN · FR · PT · IT · DE · TH · FIL

Resultados finales:

- validación de catálogo: **1316/1316 claves por locale**;
- runtime strict: **4678/4678**;
- no resueltos: **0**.

El motor PDF incorpora copy para los 8 idiomas y soporte tipográfico específico para tailandés con fallback controlado.

## 10. QA

Gate específico R77:

**24/24 PASS**

Regresión acumulativa final:

**`npm run build` → EXIT 0**

Incluye `npm test` completo y build posterior. Entre los gates acumulativos confirmados:

- R77: **24/24**;
- R76: **10/10**;
- R75: **10/10**;
- R36: **49/49**;
- R73: **7/7**;
- R72 Release: **22/22**;
- Commercial Continuity: **18/18**;
- Identity + Spectator: **15/15**;
- Showcase Seller Center: **13/13**;
- Events Operations Center: **15/15**;
- Sidebar: **9/9**;
- Reputation + Catalog: **14/14**.

Los tests históricos se adaptaron únicamente cuando comprobaban literalmente una etiqueta antigua sustituida por la nueva arquitectura, preservando el contrato funcional original.

## 11. Build y Android

- Web/PWA build: **20128**.
- Android `versionCode`: **20128**.
- Android `versionName`: `2.0.0-rc.13-r77-premium-analytics-reports`.
- Service Worker: `kombax-build-20128`.
- Paridad: **452 archivos · web = dist = Android**.
- Hashes críticos de Analytics, CSS, Showcase, Events, repositories y Service Worker: coincidentes en las tres copias.
- Android preflight: **4/5**.

Único pendiente Android: `android/keystore.properties` local para firma release. No se distribuye en el ZIP.

## 12. Seguridad y performance

### R77 específico

- 0 tablas públicas nuevas;
- RPC privadas con anon/PUBLIC revocados;
- bucket de reports privado;
- Edge Function con JWT obligatorio;
- no se incluyen credenciales, keystore ni claves privadas;
- informes minimizan PII.

### Deuda histórica global de Supabase

La auditoría global mantiene avisos anteriores al alcance de R77. Entre ellos:

- 168 tablas RLS sin policy (`INFO`);
- 50 funciones SECURITY DEFINER ejecutables por anon (`WARN`) históricas;
- 516 funciones SECURITY DEFINER ejecutables por authenticated (`WARN`), categoría que también incluye RPC autorizadas intencionadamente como las de R77;
- protección contra contraseñas filtradas desactivada (`WARN`).

Advisor de rendimiento global:

- 215 foreign keys sin índice de cobertura (`INFO`);
- 282 índices reportados como no usados (`INFO`);
- 1 índice duplicado histórico en `informes_financieros` (`WARN`).

R77 no añade tablas ni índices duplicados. Esta deuda se documenta como backlog global y no se oculta como si la release tuviera cero warnings.

## 13. Despliegues

No realizados:

- GitHub push;
- Netlify deploy;
- Google Play;
- release Android firmada.

Supabase sí fue actualizado porque estaba expresamente autorizado en la orden de trabajo.

## 14. Estado de freeze

**PILOT FREEZE CANDIDATE**.

Código, backend R77, QA automatizada, i18n, build y sincronización Web/Android están cerrados. Para elevar a **PILOT FREEZE READY** quedan únicamente comprobaciones externas que requieren el entorno del piloto:

1. smoke autenticado real en Mi Showcase/Events y generación PDF;
2. smoke multiclub real cambiando de club;
3. firma release Android con el keystore local y prueba en dispositivo.

## 15. Base válida siguiente

Una vez verificado el ZIP y su SHA-256, **R77/build 20128 sustituye a R76/build 20127 como única base acumulativa válida para el siguiente desarrollo de KOMBAX**.
