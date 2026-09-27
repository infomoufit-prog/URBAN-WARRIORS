# KOMBAX R93 · Correcciones de uniformidad estética y experiencia

**Base acumulativa:** R92, build 20145. **Entrega:** R93, build 20146. **Fecha:** 24 de septiembre de 2026.

## Alcance aplicado

- Se conserva la identidad actual de KOMBAX y los acentos propios de Social, Events, Showcase y gestión. El centro de recursos mantiene sus colecciones, guías por perfil y acordeones.
- La puerta pública ofrece enlaces visibles a privacidad, condiciones y soporte. El directorio deja fuera los clubes QA. Los textos públicos de planes explican qué ocurre al solicitar o elegir un plan sin revelar fases internas.
- Showcase público excluye registros marcados como demo o QA y fichas sin descripción útil. La gestión Mi Showcase muestra una cabecera más compacta. Las promociones para fundadores describen la invitación sin prometer un beneficio aún indefinido.
- Events público separa registros internos de la cartelera y bloquea enlaces genéricos a la portada como destino de compra o inscripción. No anuncia entradas a la venta si falta un destino válido. Los estados de Ticketing en gestión distinguen solicitud, autorización, configuración y venta.
- Finanzas sitúa primero los indicadores clave, pliega la configuración de cobros y aclara cuándo Stripe sigue pendiente. Los métodos de pago se nombran con lenguaje comprensible y el porcentaje de morosidad respeta el formato local.
- Al cambiar de ruta se cierra el modal de la vista anterior. Recursos aumenta texto y áreas táctiles en móvil. Alumnos deja las dos acciones frecuentes a la vista y reúne el resto en «Más acciones»; su cabecera distribuye mejor los controles.
- Ayuda enlaza el centro de Guías KOMBAX como entrada principal de aprendizaje. Notificaciones diferencia los avisos sin leer que requieren acción y corrige el singular.
- Las nuevas cadenas visibles se incluyen en ES, EN, FR, PT, IT, DE, TH y FIL.

## Comprobaciones

- Recorridos locales en escritorio y móvil de puerta pública, directorio, planes, Showcase, Events, recursos, alumnos, finanzas, ayuda, notificaciones y Mis Eventos. Se comprobó ausencia de desbordamiento horizontal en las vistas móviles intervenidas.
- Auditoría estricta de textos de interfaz: 0 cadenas pendientes. Catálogos completos: 1698 claves por cada uno de los ocho idiomas.
- Pruebas acumulativas de regresión y construcción determinista de `web`, `dist` y Android.

## Límites para la salida pública

- El contenido de demostración se oculta en las superficies comerciales. Por ello, si todos los eventos del entorno son muestras, la cartelera pública aparecerá vacía hasta que exista un evento real publicado.
- Esta entrega no modifica registros del servidor ni acredita cobros reales, venta de entradas, lectura QR, dispositivos físicos, cuentas de todos los perfiles o certificación de accesibilidad. Esos recorridos requieren datos y dispositivos controlados antes de abrir el piloto al público.
