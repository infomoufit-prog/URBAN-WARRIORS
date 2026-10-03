# R118 FIX03 · Cuenta y espacios

Base congelada: GitHub main 7dd7c7ed39df13bb67880685c7c2df875b43f267, build 20177. Acumulativa sobre FIX02. Sin push ni despliegue web. Sin nuevos cambios remotos en Supabase.

Dos tarjetas principales y acceso con correo/contraseña a Mi cuenta. La cuenta gratuita se explica dentro del registro. El alta especial de Club Piloto conserva su ventana y cupo; los códigos de club siguen disponibles para incorporación.

Mi cuenta separa clubes y perfiles. Las relaciones activas de equipo se consultan bajo RLS para el usuario autenticado y se agrupan por club; los roles se traducen y se conserva el logo. Las solicitudes de verificación y las invitaciones de federación conservan sus controles.

Cambiar espacio utiliza la sesión Auth existente y reconstruye la identidad global. Tras una lectura válida elimina la selección del club, permisos, caché de contrato y datos del contexto anterior. Entrar al club vuelve a comprobar membresía activa y carga el contrato de permisos. Un intento rechazado restaura la identidad anterior; no se concede acceso a partir de una tarjeta ni de un perfil verificado.

El acceso normal y la restauración de una sesión global abren Mi cuenta. Los enlaces transaccionales y los enlaces de perfiles conservan su recorrido. Los intentos de registro/alta piloto y el perfil elegido se conservan. El siguiente formulario se abre después de cerrar el formulario de autenticación, evitando su cierre accidental.

Comprobaciones: npm run build, legal gate PASS, 69 suites PASS, 3 incidencias de traducción heredadas, 0 fallos nuevos; 358 módulos y 832 imports locales validados; 624 archivos iguales en web, dist y assets Android. Navegador: 13 recorridos con fixtures, cero errores JavaScript y sin desbordamiento en móvil. Ver docs/qa/COMPROBACION_ACCESO_FIX03.json. Se verificaron las columnas y políticas de lectura de miembros_club y clubes en Supabase; sin modificaciones.

Los casos de navegador simulan autenticación y respuestas de cuentas. No equivalen a una prueba con correo real, documentos reales, cobro Stripe o dispositivos Android. Los pendientes de ESTABILIZACION_PILOTO_FIX02.md continúan vigentes.
