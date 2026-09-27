# KOMBAX · Auditoría de incorporación del plan WORK

Base única: ZIP acumulativo `KOMBAX_20149_R96_MIGRATION_IMPORT_ACCUMULATIVE_FINAL.zip`, extraído en `work/kombax-r97`. El PDF `KOMBAX_PLAN_IMPLEMENTACION_WORK.pdf` amplía los requisitos de producto; su referencia a otro ZIP no cambia esta base.

| Área | Estado en R96/R97 | Intervención |
|---|---|---|
| Cuenta e identidad | Hay cuenta, perfiles directos, club y espectador; la página de precios equiparaba indebidamente cuenta gratuita y espectador. | Hecho: corregido el lenguaje principal y retirada la obligación de escoger plan de la solicitud de identidad. Falta comprobar el alta de cada entidad con cuentas reales. |
| Club y miembros | Hay membresía, solicitud y gestión del club en rutas distintas. | En curso: entrada “Acceso clubes y miembros” y dos rutas sobre el buscador existente; una ficha asociada al correo permite solicitar la vinculación, y los demás casos envían un mensaje visible en la gestión del club. Tras iniciar sesión se retoma el club elegido. Si el club no aparece, se prepara un correo de invitación que envía el usuario. La aprobación/rechazo existente exige rol de Dirección o Secretaría, sin plan. Falta probar el circuito con cuentas reales. |
| Social | El permiso de publicación de miembro exige identidad social activa, socio activo, fecha de nacimiento y permiso del club (`249_kombax_identity_memberships_media_r58.sql`). | Verificarlo con club y miembro reales del piloto; no convertir automáticamente fichas privadas en perfiles públicos. |
| Perfiles y Descubrir | Hay listado general de perfiles y Descubrir específico. El miembro ya tiene `apodo_deportivo` opcional, independiente de su slug, y el directorio de miembros lo busca. | Mantener ambas superficies diferenciadas; verificar que al pasar de Miembro a Competidor se conserva el alias y se busca en los dos contextos. |
| Capacidades | Ya existen `kombax_capacidades` y `kombax_entitlements`; planes y activaciones los usan. | Extender el motor existente para fuente de acceso, límites, prueba y estados; no crear un segundo sistema. |
| Planes y precios | El catálogo local y el remoto muestran 29/47/79 € Founder y 36/59/99 € estándar; el PDF fija Club 23,90 € y Premium 37,90 € mensuales más IVA, Multiclub desde 29,90 € más IVA, y deja Enterprise, marcas y federaciones sin precio definitivo. Existe un PDF comercial antiguo en la web. | Catálogo R98 y resumen comercial creados. Club/Premium muestran los nuevos importes pero su solicitud está cerrada hasta enlazar Billing: el motor R64 aún activaría condiciones anteriores. No se cambian contratos vigentes. Las matrices de capacidades R98 están vacías; no se debe afirmar que el motor unificado está terminado. |
| Trial | La fase R97 prepara una demostración segura de 150 créditos y 15 días, cerrada al público; el PDF exige además prueba de plan con método de pago verificado y renovación. | Modelar dos accesos distintos o resolver la sustitución expresamente. Mantener cerrado el inicio público hasta que facturación, consentimiento y privacidad estén probados. No activar renovaciones automáticas a partir de un simple registro. |
| Showcase | Ya distingue escaparate de Commerce y +25 de ampliación; hay límites de modelos. | Verificar que el límite cuenta modelos y que la ampliación nunca activa Commerce. Previsualizar capacidad bloqueada dentro de la app. |
| Events | Publicar, destacar y Ticketing son acciones distintas en la oferta actual. | Comprobar autorización y compra por evento, QR y lector, incluida la experiencia de miembro piloto. |
| Multiclub | Hay ámbitos y sedes por club. | Conservar aislamiento de datos y permisos; cobrar a la organización sin duplicar clubes por sede. |
| Asistencia IA | La fase R97 añade monedero, reservas, consumo y panel; aún falta paquete compilado y despliegue de web. | Completar pruebas, compilar web/Android, documentar saldos y empaquetar de forma acumulativa. |

## Secuencia de cambio

1. Cerrar la fase R97 de piloto y Créditos IA, con compilación y pruebas de permisos.
2. Corregir textos y navegación de alta para que cuenta gratuita, identidad, vínculo y plan se entiendan por separado.
3. Versionar oferta comercial y compatibilidad con contratos; armonizar catálogo remoto, interfaz y PDF de precios antes de hacer seleccionables los nuevos precios.
4. Implementar trial de plan con método de pago validado en un circuito separado de la demostración segura, con estados y eventos de facturación verificables. Abrirlo al público solo después de pruebas reales en sandbox.
5. Completar previsualizaciones de capacidades y pruebas de punta a punta de Showcase, Events, Ticketing, Multiclub, Social y migración.

## Bloqueos de activación real

- No hay identificadores confirmados de los 4–5 clubes piloto ni autorización para atribuir beneficios a cuentas concretas por nombre.
- El precio final de Enterprise, Marca y Federación y la tarifa anual nueva no están definidos en el PDF.
- La prueba con cobro automático requiere producto y precio coherentes en Stripe, consentimiento explícito y validación del método de pago. Ninguno de esos hechos se deduce de la mera presencia de interfaces o de una solicitud de plan.
- La cuenta Stripe de KOMBAX no se pudo consultar desde esta sesión: el conector solicita autenticación. La petición de conexión ya está enviada al usuario. Hasta obtenerla y probar checkout/webhooks en sandbox, la nueva contratación y el trial de plan siguen cerrados.
- La interfaz nueva contiene textos recientes solo en español; falta trasladarlos al sistema de ocho idiomas y pasar la puerta de traducciones del producto.
