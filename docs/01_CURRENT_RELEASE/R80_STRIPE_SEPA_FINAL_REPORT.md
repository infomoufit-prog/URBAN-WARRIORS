# KOMBAX R80 · Stripe Connect universal + SEPA · Final Report

## Release
- Release: **R80**
- Build: **20131**
- Version Android: `2.0.0-rc.13-r80-stripe-sepa-payments`
- Base acumulativa: **R79 build 20130 + corrección fullscreen de vídeo**
- Clasificación: **PILOT IMPLEMENTATION CANDIDATE**

## Objetivo completado
R80 amplía el sistema existente de Stripe Connect de KOMBAX para convertir los cobros en una capacidad transversal por identidad comercial, con métodos de pago activables de forma independiente y un primer flujo operativo completo de domiciliación SEPA para cuotas recurrentes de Club.

### Identidades cubiertas
- Club.
- Federación.
- Marca / vendedor de Showcase.
- Organizador profesional de eventos.
- Arquitectura preparada para cualquier futura identidad a la que un plan o activación conceda capacidades de Commerce, Ticketing u otros servicios cobrables.

## Arquitectura económica preservada
- Se mantiene **una única cuenta Stripe Connect por identidad comercial**, no una cuenta por producto/servicio.
- Se mantienen **Direct Charges**: el cobro pertenece a la cuenta conectada del Club/Federación/Marca/Organizador.
- KOMBAX no custodia fondos ni se convierte en merchant of record del servicio del tercero por esta implementación.
- Tarjeta y SEPA se gestionan como **métodos independientes** sobre la misma cuenta Connect.
- Showcase Commerce y Ticketing inmediato mantienen tarjeta como método inmediato.
- SEPA se reserva a flujos recurrentes/diferidos compatibles; en R80 el flujo completo se aplica a cuotas de Club y contempla Federación como identidad recurrente compatible.

## Cambios funcionales
### Centro premium de cobros y Stripe
- Nuevo centro reutilizable de pagos con estado de Stripe, payouts, tarjeta y SEPA.
- Activación/desactivación independiente de Tarjeta y Domiciliación SEPA.
- Acceso a guía operativa y KOMBAX Assist desde el propio centro.
- Integración en Finanzas de Club, hubs gestionados, Showcase/Marca, Events/Organizador y Federación según permisos/capacidades.

### SEPA para cuotas de Club
- Setup mediante Stripe Checkout en `mode=setup` con `sepa_debit`.
- Customer independiente dentro de la connected account del Club.
- Mandato asociado a connected account + pagador + Club + socio.
- Soporte de alumno adulto y tutor/pagador autorizado.
- KOMBAX no almacena IBAN completo: conserva IDs Stripe, estado de mandato, `last4` y metadatos mínimos.
- Cobro posterior mediante PaymentIntent `sepa_debit`, `off_session`, como Direct Charge en la cuenta conectada.
- Estados de cuota contemplados: pendiente, procesando, pagada, fallida, reembolsada y disputada.
- Conciliación por webhook de `payment_intent.processing`, `payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refunded`, `charge.dispute.created`, `mandate.updated` y `setup_intent.succeeded`.

## Seguridad y privacidad
- `stripe-sepa` exige JWT.
- Secretos Stripe permanecen exclusivamente server-side.
- El IBAN completo nunca se persiste en tablas R80 ni se devuelve al frontend.
- Operaciones internas de creación/conciliación quedan restringidas a `service_role`.
- Gestión/toggles de métodos se valida por identidad, rol y permiso.
- Auditoría de patrones de secretos: **0 coincidencias de credenciales live**.
- Archivos sensibles incluidos: **0** `.env` reales, `.jks`, `.keystore`, `.p12`, `.pfx`, `.pem` o `keystore.properties`.

## Internacionalización
- Nuevo catálogo `payments.js` en ES, EN, FR, PT, IT, DE, TH y FIL.
- Auditoría estricta R79/R80: **0 unresolved**.
- Paridad de claves de pagos entre los 8 idiomas: PASS.

## Guía y Assist
Incluido dentro de la plataforma y del ZIP:
- `web/assets/docs/GUIA_KOMBAX_COBROS_STRIPE_SEPA_R80.pdf`
- Copias idénticas en `dist/` y Android embebido.

La guía tiene **13 páginas** y cubre:
- Clubes y domiciliación de cuotas.
- Tutores/pagadores.
- Marcas / vendedores de Showcase.
- Organizador profesional / Events / Ticketing.
- Federaciones.
- Estados SEPA, devoluciones/disputas y buenas prácticas.
- Uso de KOMBAX Assist sin compartir IBAN completo, claves o documentación sensible.

Validación PDF:
- Openable: PASS.
- Encrypted: no.
- 13 páginas.
- Render visual: PASS; sin cortes, solapes, glifos rotos ni páginas defectuosas.

## QA final
- Gate R80 específico: **26/26 PASS**.
- `npm test`: **EXIT 0**.
- Auditoría i18n estricta: **0 unresolved**.
- Build determinista: **465 archivos · web = dist = Android**.
- Android versionCode: **20131**.
- Firebase: presente.
- Android preflight: **4/5**. Único pendiente externo: `android/keystore.properties` local para la firma definitiva; no se incluye por seguridad.

## Scorecard de salida
| Área | Estado |
|---|---|
| Conservación R79 + fix vídeo | PASS |
| Stripe Connect universal por identidad | PASS |
| Direct Charges preservados | PASS |
| Tarjeta y SEPA independientes | PASS |
| Capacidad `sepa_debit_payments` | PASS |
| SetupIntent/Checkout setup para SEPA | PASS |
| Customer por connected account | PASS |
| Tutor/pagador autorizado | PASS |
| No almacenamiento de IBAN completo | PASS |
| Cobro SEPA off-session | PASS |
| Estados async + webhook | PASS |
| Reembolso/disputa de cuota | PASS |
| Club Finanzas | PASS |
| Federación | PASS |
| Marca / Showcase | PASS |
| Organizador profesional / Events | PASS |
| Ticketing inmediato protegido de SEPA pendiente | PASS |
| Assist | PASS |
| Guía PDF integrada | PASS |
| i18n 8 idiomas | PASS |
| Web/PWA | PASS |
| Android assets | PASS |
| Regresión acumulativa | PASS |
| Firma Android local | PENDIENTE EXTERNO |
| Smoke real con cuenta Stripe TEST | PENDIENTE OPERATIVO |

## Validación externa aún necesaria antes de cobros reales
El código queda preparado y validado estáticamente/contractualmente, pero antes de activar dinero real corresponde realizar un smoke en **Stripe test mode** con una connected account real de pruebas:
1. Completar onboarding Connect de una identidad de prueba.
2. Confirmar que Stripe activa `card_payments` y `sepa_debit_payments`.
3. Crear un mandato SEPA con un IBAN de prueba oficial de Stripe.
4. Ejecutar una cuota en estado `processing` y esperar/transicionar a `succeeded`.
5. Probar fallo, refund/dispute y revocación del mandato.
6. Confirmar que el ledger/cuota KOMBAX concilia exactamente con el evento Stripe.

No se ha realizado ninguna mutación live en la cuenta Stripe del propietario durante esta fase.

## Continuidad
**R80 build 20131** sustituye a R79 como nueva base acumulativa válida para el siguiente trabajo, una vez aplicado el SQL/Edge Functions en el entorno objetivo y completado el smoke Stripe TEST correspondiente.
