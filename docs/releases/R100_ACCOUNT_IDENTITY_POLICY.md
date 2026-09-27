# R100 · Cuentas por tipo de perfil

## Regla de producto

Cada correo queda asociado al tipo de cuenta escogido: Club, Competidor, Federación, Marca, Profesional o Media. Una cuenta de Miembro de club puede solicitar un perfil de Competidor conservando su identidad Social. Ser gestor de Club no concede acceso a una cuenta de Federación o Marca.

## Cambios

- Retirado de «Mi perfil» del Club el acceso a «Mis identidades» que permitía mezclar tipos.
- El selector de perfiles solo presenta opciones permitidas para la cuenta autenticada. Un Miembro ve Competidor; una cuenta con tipo ya asignado no ve «Solicitar perfil».
- La solicitud de Competidor iniciada por un Miembro exige escoger su identidad de Miembro para conservar Social y la red.
- La migración `271_kombax_account_identity_exclusivity_r100.sql` protege las inserciones de perfiles y solicitudes también cuando se invoca la API fuera de la interfaz. No borra perfiles piloto existentes.
- La migración `272_kombax_account_type_lock_r100.sql` fija el tipo al registrarse, antes incluso de completar la primera solicitud. Las cuentas anteriores quedan fijadas en su primera solicitud nueva.

## Flujos comprobados

| Cuenta | Entrada y funciones | Límite |
| --- | --- | --- |
| Club | Login, pantalla de cuatro ecosistemas, gestión privada del club, Social, Showcase, Events y recursos según permisos. | No solicita Federación, Marca ni Competidor desde esa cuenta. |
| Federación | Identidad institucional, administración federativa, federados, licencias, equipo, clubes relacionados, Events, Social, planes y Assist. | Relacionarse con clubes no abre sus alumnos ni finanzas privadas. |
| Marca | Business Hub, catálogo Showcase, campañas, colaboraciones, patrocinios, equipo, Social y Events según capacidades. | No obtiene Club ni Federación. El comercio exige activación separada. |
| Competidor | Perfil deportivo, Social, Events, disponibilidad en Discovery, licencias, competiciones, oportunidades y representación según capacidades. | No obtiene una cuenta institucional. |
| Miembro | Espacio del club y Social según permisos; puede solicitar Competidor con continuidad del perfil Social. | No puede solicitar una cuenta institucional desde el mismo correo. |

La visibilidad de módulos depende del estado de verificación y las capacidades concedidas. El código de los entornos gestionados está en `web/js/modules/managed-profile-hub.js`.

## Pruebas y límites actuales

- Política local: 11 escenarios correctos; comprobaciones R28 (13/13) y R29 (9/9); sintaxis del gateway correcta.
- Ambas migraciones aplicadas al proyecto piloto de Supabase el 26-09-2026. Los triggers de alta, perfil y solicitud aparecen habilitados. Una solicitud cruzada de Marca desde un propietario de Federación fue rechazada dentro de una prueba transaccional y no quedó registrada.
- La cuenta piloto `infomoufit@gmail.com` ya tenía Club y una Federación ficticia antes de esta corrección. Se conserva para no perder datos y se impide crear nuevos tipos. Para separarla hacen falta otra cuenta y una decisión sobre el traslado de la Federación demo.
- Correo de prueba enviado desde `infomoufit@gmail.com` a `soporte@kombax.es` el 26-09-2026. Gmail confirma el envío. En la comprobación posterior no había respuesta en Gmail ni mensajes en las tablas `ticket_messages` / `email_outbox`; la recepción en Zimbra y la automatización de respuesta siguen sin acreditarse.
- No se crearon cuentas nuevas de Marca o Competidor: cada tipo necesita su propio correo y completar el registro y la aceptación legal del titular.
