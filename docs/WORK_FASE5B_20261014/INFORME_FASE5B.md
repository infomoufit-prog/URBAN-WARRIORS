# KOMBAX — Fase 5B · Implementación parcial federativa / Instagram / Events

Fecha de referencia: 2026-10-14. Base exacta: acumulativo 5A `c8a5af0035882606341aa5c090c3c7ac5b8dcce7c5546c225a141ce408cd2e65`.

## Implementación acumulativa local de esta tarea

- Mi Federación Premium: sobre el contexto autorizado `app_kombax_federation_context_v200`, lista de federados, búsqueda por deportista/club/temporada/disciplina, filtro de estado y exportación CSV filtrada. El CSV neutraliza prefijos de fórmulas y advierte que la consulta RPC tiene límite de 500 licencias; NO indica un informe completo si está paginado.
- Events General/VIP: editor de categorías personalizadas con nombre, descripción, precio, cupo, zona, instrucciones y color, usando RPC R265 ya existentes; **guardar mantiene borrador**. Integración de catálogo público de categorías R266 en el formulario de compra; si el catálogo falla, el checkout se bloquea para evitar cobrar erróneamente una entrada básica. Para categorías habilitadas por servidor, pasa `ticket_category_id` al Stripe Checkout existente. La categoría, puerta, instrucciones y color se reflejan en entrada digital e imprimible mediante el snapshot de pedido, sin alterar el token QR.
- Instagram: interfaz de conexión explica el flujo de imagen subiéndola en KOMBAX Social y vinculándola mediante el post público. Vista previa de imagen, texto y enlaces HTTPS incluidos en dicho post. Se mantiene autorización explícita para la publicación externa. Enlaces en feed de Instagram normalmente no son clicables.

## Backend: solo auditoría, no se han aplicado migraciones nuevas en esta fase 5B

Supabase había recibido R265 y R266 en tareas anteriores; no se duplican. `app_kombax_event_ticket_categories_public_r266` está habilitado para `anon` y `authenticated`; las funciones de lectura/edición administrativa requieren autenticación y `app_kombax_evento_puede_gestionar_v160` en el servidor.

Observado en este control: 0 categorías de ticket configuradas, 0 categorías vendibles, 0 conexiones Instagram, 0 publicaciones Instagram, 0 licencias federativas y 0 relaciones de clubs federativos. No realizar una prueba E2E con cuentas reales sin autorización específica.

## QA y regresión

- 40/40 comprobaciones nuevas de contrato/UI/sincronización.
- 23/23 test Meta simulado (anterior existente).
- 8/8 test de transporte Meta.
- 94/94 navegación premium fase 4.
- 28/28 Material y Showcase fase 5A.
- 52/52 inventario R89.
- 26/26 multiespacio fase 1, 17/17 aislamiento financiero, 32/32 inscripciones/licencias, 49/49 finanzas R264.
- `node --check` de los cuatro archivos modificados y coherencia exacta entre `web`, `dist`, `android/app/src/main/assets/www`.

**Limitaciones:** suites históricas R33/R62.5.2/R62.5.3 bloqueadas por documento antiguo ausente o expectativas de texto históricas que no se han considerado regresión sin un baseline. No hay compilación Android, test visual de navegador/PWA, test Stripe real, venta de tickets General/VIP, conexión OAuth Meta ni publicación externa. No declarar producción lista.

## Próximos hitos de la fase 5

1. Flujo completo de publicación desde Events y Showcase a Instagram, con selección/subida de recurso, enlace visible en KOMBAX y las opciones realmente admitidas por Meta para cada tipo de publicación. La subida en Social sí existe, pero **no se ha creado aquí un uploader de imagen independiente desde el modal Instagram**.
2. Validación de Meta OAuth real con una cuenta profesional expresamente autorizada y callback en Meta configurado.
3. Habilitación de ventas por categoría solo tras pruebas Stripe/webhook, inventario concurrente, QR, reembolso y restricciones legales. Editor guarda borrador y no habilita `checkout_enabled`.
4. Federación: validar con equipo real y licencias autorizadas, reglas de privacidad, exportación parcial por límite RPC y pruebas responsive. Mejorar paginación en origen antes de informes exhaustivos.
5. Resolver divergencia de nombre R120 FIX22 frente a versionado interno R118/build 20178 antes de publicar.

**Restricciones observadas:** sin push GitHub, sin deploy Netlify, sin transacciones de compras, sin publicaciones en Instagram y sin escrituras nuevas en datos de clientes.
