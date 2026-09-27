# PROMPT MAESTRO DE CONTINUACIÓN - KOMBAX
## Bloque funcional 1 · Fases 1-5

**Base obligatoria de entrada:** `KOMBAX_20134_R81_PREBLOCK_TERRITORIAL_GUIDES_DETAILED_MASTERPROMPT_ACCUMULATIVE_FINAL.zip`

## 0. INSTRUCCIÓN PRINCIPAL

Trabaja exclusivamente sobre el ZIP acumulativo indicado arriba. Ese ZIP es la **única base válida**. No reconstruyas KOMBAX desde archivos anteriores, no sustituyas módulos por prototipos y no elimines funcionalidades existentes para simplificar el trabajo.

Tu misión es ejecutar el **Bloque funcional 1 del Plan Maestro KOMBAX, Fases 1 a 5**, de forma acumulativa y segura. Cada fase debe partir del ZIP certificado de la fase anterior. Al terminar **cada fase**, debes entregar un ZIP completo, autosuficiente y verificado que se convierta en la única base de la fase siguiente.

No preguntes al usuario por decisiones ya definidas en este prompt. Antes de modificar código, audita el estado real de la base y reutiliza la arquitectura existente. Si el código actual contradice una memoria histórica, el código y las migraciones de la base actual son la fuente técnica de verdad; documenta la discrepancia antes de cambiarla.

No realices cobros reales, débitos, reembolsos, mandatos o movimientos de dinero durante QA. Utiliza entornos/test data cuando sea necesario y conserva la separación entre código preparado y activación real.

---

# 1. CONTEXTO DEL PRODUCTO

KOMBAX es una plataforma SaaS para clubes, federaciones, marcas, organizadores y perfiles de deportes de contacto. Los grandes ecosistemas actuales son:

- KOMBAX Social.
- Mi Club / Mi Federación / Mi Perfil / Mi Marca / identidad activa equivalente.
- KOMBAX Showcase.
- KOMBAX Events.
- KOMBAX Payments / Finance.

El producto funciona con **una cuenta por correo**, admite multiclub y multientidad y debe mantener aislamiento estricto de datos por identidad activa. Nunca deben mezclarse finanzas, pedidos, eventos, catálogos o permisos de dos entidades distintas.

Infraestructura:

- Supabase + RLS/RPC.
- Netlify para frontend y functions/build.
- GitHub.
- Stripe Connect.
- Resend/FCM donde corresponda.
- PWA.
- Android APK/AAB.
- base iOS preparada.
- 8 idiomas: ES, EN, FR, PT, IT, DE, TH y FIL.

Identidad visual: dark premium. Social rojo/anaranjado, Events cian/neón, Showcase amarillo/dorado. Todo cambio debe respetar el lenguaje visual existente.

---

# 2. ESTADO CERTIFICADO QUE NO DEBES REGRESAR

La base de entrada es R81 build 20134. Conserva íntegramente todo lo anterior.

## Pagos existentes

KOMBAX Payments ya dispone de:

- Tarjeta online mediante Stripe Connect.
- Domiciliación SEPA.
- Tap to Pay Android mediante Stripe Terminal nativo.
- base Tap to Pay on iPhone nativa.
- fallback Safari/PWA mediante Stripe Checkout + QR/enlace.
- reconciliación por webhook.

Arquitectura general: los comercios/clubes/organizadores cobran en su **Stripe Connected Account** cuando así corresponde. KOMBAX no debe custodiar dinero ajeno.

No reutilices automáticamente reglas de comisión de Showcase/Events para cuotas de club. Antes de modificar fees inspecciona la lógica comercial real de la base. No supongas que todos los flujos tienen comisión cero ni que todos tienen application fee.

## Android

La Fase 0 corrigió el bloqueo `BuildConfig.DEBUG` del módulo Terminal. La implementación correcta usa el estado `ApplicationInfo.FLAG_DEBUGGABLE`. No reintroduzcas el `BuildConfig` incorrecto ni importes `com.stripe.stripeterminal.BuildConfig`.

La firma Android es local. No introduzcas en el ZIP:

- `android/keystore.properties` real;
- JKS/keystore;
- passwords;
- secretos de firma.

## iOS

La fuente iOS existe, pero producción requiere macOS/Xcode, Apple Developer, firma, provisioning y entitlement Tap to Pay on iPhone. No incluyas `.p12`, private keys ni mobileprovision.

## Backend live

El proyecto Supabase vigente es el de KOMBAX y ya contiene las migraciones R80/R81. Las funciones de Stripe Connect, Checkout, SEPA, Terminal, webhook, refund y account-finance están desplegadas. Si una fase necesita nuevas migraciones, deben ser **aditivas, reproducibles y seguras**. No reapliques manualmente una migración ya aplicada.

Para DDL usa el flujo de migraciones de Supabase. Tras cada despliegue verifica live schema/RPC/functions y ejecuta advisors relevantes sin debilitar RLS.

---

# 3. REGLAS DE NEGOCIO OBLIGATORIAS

1. Compra comercial bloqueada para menores de 18 años.
2. El pago de cuotas de un menor por su tutor no debe confundirse con una compra comercial realizada por el menor.
3. El vendedor/organizador debe tener el estado de verificación/capacidad requerido antes de cobrar.
4. Un pedido no se considera pagado porque el frontend regrese a una URL de éxito: **el webhook/backend es la fuente de verdad**.
5. Idempotencia obligatoria en creación de pagos/pedidos críticos.
6. No almacenar datos completos de tarjeta ni IBAN bruto.
7. Mantener trazabilidad de pago, devolución, disputa y fallo.
8. Identidad activa = contexto financiero/comercial. Club A nunca comparte los datos de Club B, Marca C o Federación D.
9. `Explorar Showcase` público no debe bloquearse por un fallo de `Mi Showcase` privado.
10. Productos archivados y eliminados deben respetar la arquitectura actual; no rompas referencias de pedidos históricos.
11. Respeta la separación Showcase Display vs Showcase Commerce.
12. No inventes precios, límites comerciales o fees. Consulta el catálogo/código vigente antes de presentar o cambiar importes.

---

# 4. BLOQUE 1 - FASES 1 A 5

## FASE 1 - AUDITORÍA FUNCIONAL DE ARRANQUE Y FREEZE PARA COMMERCE/FINANCE

Antes de implementar Commerce nuevo:

### Auditoría

Revisa como mínimo:

- Showcase público y privado.
- modelos/productos/variantes.
- vendedor/`showcase_provider` y contextos multientidad.
- Commerce actual.
- carrito/checkout si ya existen total o parcialmente.
- pedidos y order_items.
- stock y movimientos.
- Stripe Connect.
- `stripe-checkout`.
- refunds.
- webhook.
- reglas de platform fee/application fee.
- age gate + vendedor verificado.
- Events/ticketing para identificar motores reutilizables sin acoplarlos incorrectamente.
- Finance existente por club/profesional.
- receipts/reports/history.
- RLS/RPC/permisos.
- responsive.
- 8 idiomas.
- PWA/Android/iOS bridges.

### Resultado

Corrige únicamente bloqueos/base inconsistentes necesarios para poder realizar las siguientes fases. No añadas todavía funcionalidades ajenas al Bloque 1.

### Gate Fase 1

- tests específicos PASS;
- regresión acumulativa PASS;
- build determinista PASS;
- `web = dist = Android` cuando aplique;
- secret scan PASS;
- manifest SHA-256;
- ZIP completo acumulativo **Fase 1**.

Ese ZIP es la única base de Fase 2.

---

## FASE 2 - EXPERIENCIA DE COMPRA KOMBAX SHOWCASE

Implementa una experiencia de compra real, clara y premium sin eliminar el modo Display.

### Producto Showcase Display

Cuando el vendedor no tiene Commerce activo, mantener una experiencia tipo catálogo/interés:

- precio/información cuando proceda;
- `Me interesa`;
- preguntar al vendedor/chat;
- compartir;
- no simular checkout inexistente.

### Producto Showcase Commerce

Cuando Commerce está habilitado, la ficha debe ofrecer:

- `Comprar ahora` como CTA principal;
- `Añadir al carrito`;
- precio final y moneda;
- variantes/opciones disponibles;
- disponibilidad/stock;
- cantidad;
- vendedor e identidad verificada;
- imágenes/vídeo existentes;
- condiciones relevantes de compra/entrega/devolución cuando estén disponibles;
- chat/preguntar al vendedor como opción secundaria.

No sustituyas `Me interesa` globalmente: la CTA depende de la capacidad Commerce del producto/vendedor.

### Carrito

Implementa/reutiliza carrito con:

- items y variantes;
- cantidades;
- validación de stock antes de checkout;
- subtotal/total y desglose real disponible;
- eliminación/edición;
- aislamiento por vendedor cuando la arquitectura de cobro no admita mezclar Connected Accounts en una misma transacción.

No inventes multi-seller checkout. Si Stripe/arquitectura actual trabaja por Connected Account, diseña el carrito/checkout conforme a esa limitación y explícalo en UX.

### Checkout UX

- identificación de comprador;
- age gate comercial >=18;
- dirección/datos mínimos cuando el tipo de entrega lo requiera;
- resumen de pedido;
- condiciones/consentimientos existentes;
- botón claro de pago;
- estados loading/error/cancelled/complete;
- responsive PC/móvil/PWA/Android.

### Pedidos

El pedido debe existir con estados coherentes antes/después del pago. Preserva historial y referencias aunque un producto posteriormente sea archivado.

### Gate Fase 2

Entrega ZIP acumulativo completo y documentación/QA. No continúes a Fase 3 desde archivos sueltos.

---

## FASE 3 - STRIPE CHECKOUT / CONNECT PARA SHOWCASE COMMERCE

Cierra la cadena de pago de Showcase.

### Arquitectura objetivo

`Comprador -> KOMBAX Checkout -> Stripe -> Connected Account del vendedor -> webhook -> pedido KOMBAX`

KOMBAX actúa como plataforma/software/marketplace según la arquitectura legal vigente; el dinero del vendedor no debe pasar por un saldo bancario de KOMBAX salvo un flujo comercial expresamente distinto y documentado.

### Backend

Inspecciona primero `stripe-checkout`, `stripe-webhook`, Connected Accounts, pedidos y reglas comerciales vigentes.

Debe quedar resuelto:

- Payment/Checkout Session asociado a pedido.
- Direct Charge cuando corresponda al modelo Connect vigente.
- Connected Account derivado server-side; nunca aceptar un Stripe account arbitrario enviado por cliente.
- metadata suficiente: order/provider/buyer/subject/context.
- idempotency key.
- success/cancel URL segura.
- webhook firmado.
- `checkout.session.completed`/PaymentIntent/charge/refund/dispute reconciliados según el diseño existente.
- pedido `paid` solo desde evento/backend autoritativo.
- fallo y cancelación.
- reembolso total/parcial si el motor actual lo soporta.
- conciliación financiera.
- stock reservado/descontado de forma consistente evitando doble venta cuando sea razonablemente posible.

### Métodos

Tarjeta es obligatoria. Apple Pay / Google Pay u otros wallets solo deben mostrarse cuando Stripe y el dispositivo/configuración realmente los ofrezcan. No prometas un wallet que no esté habilitado.

### Seguridad

- no secretos en frontend;
- no client secret persistente en logs/documentación;
- no tarjeta almacenada por KOMBAX;
- no cargo real durante QA;
- pruebas en entorno seguro/test.

### Gate Fase 3

- pruebas happy path + fallo + cancelación + webhook idempotente + refund cuando corresponda;
- Supabase migration/function live si hay backend nuevo;
- regression/build/security;
- ZIP acumulativo completo.

---

## FASE 4 - KOMBAX FINANCE MULTIENTIDAD

Transforma Finance en un motor transversal sin destruir las finanzas de Club existentes.

### Principio

Una identidad activa determina el ámbito financiero.

- Club -> cuotas, matrículas, deuda, recibos, SEPA, tarjeta, Tap to Pay y demás operaciones actuales.
- Marca/Showcase -> ventas, pedidos, ingresos, refunds, stock relacionado y pagos.
- Federación -> licencias, servicios, inscripciones y cobros permitidos por la arquitectura real.
- Organizador -> ticketing, taquilla, refunds, check-ins/ventas cuando proceda.

### Aislamiento

Nunca mezclar:

- métricas;
- pedidos;
- recibos;
- saldos operativos;
- Connected Accounts;
- métodos habilitados;
- informes;
- permisos.

entre identidades diferentes.

### Arquitectura

Reutiliza el motor común y crea adaptadores/contextos en lugar de cuatro sistemas independientes. La capa visual puede variar según entidad, pero los conceptos comunes deben compartir estructuras donde sea seguro.

### Permisos

Respeta roles actuales y añade únicamente permisos estrictamente necesarios. Las funciones financieras sensibles no deben quedar abiertas a cualquier miembro autenticado.

### Datos

Showcase y Events deben alimentar Finance automáticamente. No crees una contabilidad paralela desconectada.

Ejemplo conceptual:

`Venta Showcase -> Payment -> Finance transaction/reporting`

`Entrada Events -> Payment -> Finance transaction/reporting`

`Cuota Club -> Payment -> Finance transaction/reporting`

### Gate Fase 4

Test de aislamiento multientidad obligatorio con usuarios/roles representativos. Entrega ZIP acumulativo completo.

---

## FASE 5 - MÉTODOS DE PAGO COMUNES E INTEGRACIÓN FINANCIERA

Conecta la capa financiera a los métodos de pago ya disponibles sin ejecutar todavía la gran reorganización visual de Finanzas Premium prevista para una fase posterior.

### Métodos comunes

- Tarjeta online.
- SEPA cuando sea compatible con el caso de uso.
- Tap to Pay Android.
- Tap to Pay on iPhone cuando exista app nativa/entitlement.
- QR/enlace Stripe Checkout como fallback web/PWA/iPhone sin app.
- métodos manuales existentes cuando proceda, claramente diferenciados.

### Presentación de datos

Los registros financieros deben identificar el método real utilizado para poder mostrarse después en:

- Resumen.
- Pagos.
- Recibos.
- Historial.
- Informes.
- Deuda.
- Pedidos.
- Ventas.
- Ticketing.

No hagas todavía la Fase 16 de acordeones completos, pero deja el modelo, etiquetas y fuentes de datos preparados.

### Tap to Pay

No intentes usar Web NFC para cobrar tarjetas. NFC card-present requiere Stripe Terminal SDK nativo. Safari/PWA debe mantener QR/enlace Checkout.

### Gate Fase 5 / cierre del Bloque 1

Ejecuta:

- suite específica de Fases 1-5;
- `npm test` acumulativo;
- i18n strict;
- legal gate;
- production/release build;
- web/dist/Android parity;
- Android preflight;
- iOS static/source gate;
- Supabase live verification;
- security/secret scan;
- manifest SHA-256;
- unzip/CRC verification.

Entrega un **ZIP acumulativo final del Bloque 1**. Ese ZIP será la única base del Bloque 2.

---

# 5. INTERNACIONALIZACIÓN

No introducir textos hardcoded fuera del sistema i18n salvo contenido técnico interno que no se renderice al usuario.

Idiomas activos:

- ES
- EN
- FR
- PT
- IT
- DE
- TH
- FIL

Cada fase debe terminar con:

- 0 `missing_translation`;
- 0 `undefined/null` visibles;
- gates existentes en PASS;
- mismas funciones esenciales en los ocho idiomas.

No uses traducción automática para modificar el original creado por usuarios. La arquitectura de contenido universal debe preservar original + traducción derivada.

---

# 6. UX / RESPONSIVE / CALIDAD VISUAL

KOMBAX debe conservar su apariencia dark premium existente. Antes de crear un componente nuevo, busca primero un patrón ya utilizado en Social, Showcase, Events, Finance o centros privados.

Requisitos:

- desktop;
- tablet;
- móvil;
- Android WebView;
- Safari/PWA iPhone;
- safe areas;
- navegación atrás/cerrar cuando sea necesaria;
- loading/empty/error/success;
- accesibilidad básica de labels/focus/contraste;
- no bloquear una superficie pública por fallo de un centro privado.

---

# 7. SUPABASE Y SEGURIDAD

Toda migración debe ser acumulativa y segura.

- RLS activo donde corresponda.
- Evitar políticas amplias para resolver errores de acceso.
- Preferir RPC/service functions para operaciones financieras sensibles.
- Derivar identidad/Connected Account server-side.
- Verificar roles y subject access.
- Índices para nuevas foreign keys/query paths cuando sean necesarios.
- No almacenar secretos.
- No borrar tablas/migraciones históricas salvo plan de rollback explícito y justificado.

Después de cambios live:

1. comprobar migración aplicada;
2. comprobar tablas/columnas/RPC;
3. comprobar Edge Functions ACTIVE;
4. ejecutar advisors;
5. distinguir findings históricos de nuevos findings introducidos por la fase.

---

# 8. RELEASE Y ZIP ACUMULATIVO POR FASE

Al finalizar CADA fase:

1. Actualiza versión/build de forma monotónica cuando haya cambio runtime. La base entra como 20134; no reutilices 20134 para una release funcional distinta.
2. Actualiza cache-busters/service worker/versiones Android/iOS cuando corresponda.
3. Ejecuta tests de la fase.
4. Ejecuta regresión.
5. Ejecuta build determinista.
6. Verifica `web = dist = Android` según el pipeline actual.
7. Ejecuta secret scan.
8. Genera informe técnico y QA scorecard.
9. Genera manifest SHA-256 de todos los archivos del paquete.
10. Empaqueta el proyecto COMPLETO, no un patch.
11. Ejecuta `unzip -tq` o verificación equivalente.
12. Calcula SHA-256 del ZIP.
13. Entrega ZIP + `.sha256` + informe/QA.

Nunca continúes una fase desde la carpeta anterior si ya has producido el ZIP acumulativo de la fase; extrae/usa ese ZIP como nueva base lógica y comprueba que contiene todo lo necesario.

---

# 9. CONTENIDO DEL BLOQUE PREVIO QUE DEBES PRESERVAR

La base ya contiene trabajo editorial aprobado que NO debes simplificar ni reemplazar durante Fases 1-5:

## Assets aprobados

- KOMBAX Guías.
- KOMBAX Consultoría.
- KOMBAX Formación.

Mantén originales y variantes existentes.

## KOMBAX Guías

Existe:

- colección inicial de 15 materias;
- capa España/Cataluña;
- 19 territorios (17 CCAA + Ceuta + Melilla);
- versión territorial profesional detallada;
- PDFs individuales;
- dossier maestro detallado;
- fuentes oficiales y matriz de verificación;
- arquitectura para futura búsqueda por tema/territorio/municipio/modalidad.

Regla editorial: **prohibido inventar requisitos**. Si una obligación depende de municipio, federación, recinto, modalidad o caso concreto, se etiqueta como verificación específica.

## KOMBAX Consultoría

La arquitectura y catálogo preparatorio existen, pero los precios no han sido aprobados. No inventes importes. El CTA se usa cuando una guía general ya no basta para resolver un caso específico.

## KOMBAX Formación

Es una capa privada futura, `training_enabled`, inicialmente para una federación/colegio profesional piloto. NO la hagas pública durante Fases 1-5.

No inventes cursos, horas, equivalencias, licencias formativas, certificaciones, recursos ISO, nombres de partner o precios hasta recibir documentación real.

---

# 10. PLAN POSTERIOR - NO IMPLEMENTAR TODAVÍA

Debe conservarse en documentación para los siguientes bloques.

## Bloque 2 - Fases 6-10

- Nueva Home post-login con cuatro tarjetas, orden obligatorio:
  1. KOMBAX Social
  2. KOMBAX Showcase
  3. KOMBAX Events
  4. Mi espacio - siempre última, nombre dinámico por identidad.
- Contexto inteligente de identidad.
- Social > Descubrir > Directorio de peleadores.
- Rankings/listados objetivos y transparentes.
- Integración fighter discovery con Events.

## Bloque 3 - Fases 11-15

- UI KOMBAX Guías.
- motor documental + PDFs + búsqueda territorial.
- KOMBAX Consultoría.
- catálogo/servicios/precios aprobados.
- solicitud, documentación, presupuesto/pago/seguimiento de consultoría.

## Bloque 4 - Fases 16-20

- reorganización definitiva de Finanzas Premium en acordeones;
- métodos visibles en resumen/pagos/recibos/historial/informes/deuda/pedidos/ventas/ticketing;
- KOMBAX Formación privada;
- cursos/módulos/prácticas/recursos/evaluación/licencias/certificados conforme al acuerdo real;
- piloto federación/colegio profesional;
- QA integral final.

No adelantes estas fases salvo que sea necesario crear una interfaz/contrato técnico mínimo para no bloquear el Bloque 1. Si lo haces, documéntalo como foundation y no como implementación funcional del bloque posterior.

---

# 11. FORMA DE TRABAJO

Antes de implementar cada fase:

1. audita;
2. escribe tu plan técnico interno;
3. identifica reutilización vs código nuevo;
4. comprueba impacto en Supabase, permisos, i18n, responsive y mobile;
5. implementa;
6. prueba;
7. corrige;
8. vuelve a probar;
9. empaqueta;
10. documenta.

No des por terminada una fase por haber escrito el código. Solo se cierra cuando los gates y el ZIP acumulativo pasan.

Informa de progreso de forma breve y útil. No pidas aprobación intermedia salvo que encuentres una decisión de negocio realmente no definida en este prompt que pueda cambiar dinero, responsabilidad legal o arquitectura irreversible.

---

# 12. CRITERIOS DE CIERRE DEL BLOQUE 1

El Bloque 1 no está terminado hasta que se pueda demostrar que:

- un producto Display sigue funcionando sin Commerce;
- un producto Commerce tiene Comprar/Carrito/Checkout;
- la compra crea y reconcilia pedido correctamente;
- Stripe Connect cobra en la cuenta correcta conforme al modelo vigente;
- webhook manda sobre el estado financiero;
- stock/pedido/refund mantienen coherencia;
- menores no pueden realizar compras comerciales;
- Club/Marca/Federación/Organizador tienen contextos financieros aislados;
- Finance recibe operaciones de Showcase/Events/Club sin mezclar entidades;
- tarjeta/SEPA/Tap to Pay/QR están modelados coherentemente donde corresponda;
- no se ha roto Social/Events/Mi Club/Showcase público;
- 8 idiomas pasan;
- Android/PWA pasan sus gates;
- no se han incluido secretos;
- Supabase live coincide con las migraciones necesarias;
- existe ZIP completo final y checksum.

## Instrucción de inicio

**Empieza auditando el ZIP base completo. No implementes sobre una versión anterior. Ejecuta Fase 1, ciérrala con ZIP acumulativo y continúa sucesivamente hasta Fase 5, usando siempre el ZIP cerrado de la fase anterior como única base.**
