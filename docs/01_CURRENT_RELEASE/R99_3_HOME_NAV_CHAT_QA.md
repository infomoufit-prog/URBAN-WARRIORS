# R99.3 · Inicio universal, navegación y chat

## Comportamiento

- El inicio de sesión de Club y miembros abre `Tu KOMBAX` con Social, Showcase, Events y Mi espacio, incluso si el navegador conservaba una ruta interior. La restauración de sesión empieza igual, salvo en retornos transaccionales de pago o Stripe.
- El inicio de sesión global y la restauración de la sesión global abren la misma selección de tarjetas. El flujo se comparte entre Espectador, Competidor, Profesional, Federación y Marca. `Mi espacio` lleva a las identidades y sus herramientas.
- `Inicio` en Mi Club y en los espacios de perfil directo vuelve a la selección de tarjetas.
- Las vistas interiores con encabezado y el panel inicial del club muestran Volver y Cerrar. La portada de tarjetas de perfiles directos también permite regresar o cerrar.
- Assist y Migrations muestran el mensaje enviado antes de iniciar la espera, presentan el estado de respuesta y sustituyen el estado provisional por la respuesta persistida. Se evita el envío repetido durante la espera; un fallo recupera el texto para reintentar.

## Verificación

- Navegador local, sesión CLUB MOUFIT DEMO: `Mi Club` → `Inicio` → cuatro tarjetas; `Mi espacio` → panel con Volver y Cerrar.
- KOMBAX Assist: el mensaje de prueba apareció al pulsar Enviar, mostró «Preparando respuesta…» y luego «Mensaje recibido.».
- KOMBAX Migrations, caso ficticio `KMX-2026-473488`: el mensaje apareció al pulsar Enviar, mostró «Analizando la migración…» y luego «Veo este mensaje. No he importado datos.».
- Comprobación de sintaxis de los módulos modificados y prueba de la portada premium R90: 35/35.

La ruta global se ha revisado por código y es única para todos los tipos de perfil. No se han iniciado sesiones reales separadas de cada identidad durante esta comprobación.
