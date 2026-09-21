# R77 · Auditoría Showcase + Events Analytics & Reports

**Release:** KOMBAX R77 / build 20128  
**Base auditada:** R76 / build 20127  
**Fecha:** 2026-09-16

## Alcance

Auditoría específica de la evolución de Mi Showcase, tarjetas 1:1, analítica, navegación, informes PDF, Events Analytics, resultados deportivos, permisos, multiclub, privacidad, i18n, responsive, performance y paridad Web/Android.

## Evidencia de arquitectura

### Showcase

- Explore continúa en ruta pública independiente.
- Mi Showcase continúa en ruta privada.
- El proveedor privado se resuelve por contexto activo, preservando R75.
- Analítica y reporting reciben `provider_id` explícito y backend vuelve a autorizar ese proveedor.
- La UI no implementa una vista consolidada multiclub implícita.

### Events

- Analytics/Results/Reports operan sobre `event_id` explícito.
- Backend verifica `can_manage_event_r65`.
- Resultados se leen de datos de combates existentes; no se generan ganadores ficticios.

## Datos reutilizados

R77 reutiliza tablas/ledgers existentes de:

- `kombax_showcase_elementos`;
- Showcase orders/items;
- Commerce analytics events;
- refunds/payment attempts;
- Event ticket orders/tickets;
- check-in audit;
- participantes;
- combates/resultados.

No se creó un segundo libro contable ni una tabla paralela de ventas.

## Performance

La UI usa RPC agregadas para reducir N+1 y múltiples llamadas secuenciales. Los rangos exactos se calculan en backend y se comparan con el periodo anterior equivalente.

El advisor global de Supabase devuelve deuda histórica: 215 FK sin índice, 282 índices sin uso observado y 1 índice duplicado. No se añadió ningún índice duplicado ni tabla nueva en R77.

## PDFs

`kombax-report-r77` v2:

- JWT obligatorio;
- payload autorizado con sesión de usuario;
- Storage privado;
- URL firmada 600 s;
- logo vendedor/organizador;
- cartel Events cuando existe;
- miniaturas de producto 1:1;
- tablas Showcase/Events;
- asistencia, participantes y resultados;
- rango exacto compartido con pantalla;
- sin PII de comprador innecesaria en payload operativo.

## Seguridad

RPC exact-range/report-range verificadas:

| Propiedad | Resultado |
|---|---|
| SECURITY DEFINER | PASS |
| search_path cerrado | PASS |
| anon EXECUTE | bloqueado |
| PUBLIC EXECUTE | bloqueado |
| authenticated EXECUTE | permitido |
| autorización interna provider/event | PASS |
| bucket report público | NO |
| Edge verify_jwt | SÍ |

La auditoría global contiene deuda histórica ajena a esta fase; no se declara “0 warnings”.

## Responsive

`kombax-analytics-r77.css` contiene superficies específicas para dashboard, navegación, cards 1:1, charts y tablas. El build final sincronizó 452 archivos entre Web, dist y Android.

## QA

- gate R77: 24/24 PASS;
- `npm run build`: EXIT 0;
- `npm test`: incluido y PASS;
- i18n: 1316/1316 por locale;
- runtime i18n: 4678/4678, 0 unresolved;
- Android preflight: 4/5, solo firma local pendiente.

## Conclusión

No se ha detectado una regresión arquitectónica en la separación pública/privada, contexto multiclub, Commerce o Stripe Connect. R77 cumple el criterio **PILOT FREEZE CANDIDATE**; quedan smoke autenticado real y firma Android como validaciones externas.
