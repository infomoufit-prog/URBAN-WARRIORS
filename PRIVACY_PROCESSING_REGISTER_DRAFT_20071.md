# KOMBAX · Registro de actividades de tratamiento · piloto build 20077

Registro operativo para el piloto controlado. Debe mantenerse vivo y revisarse ante cambios de finalidad, proveedor, escala o categorías de datos.

## Responsable
- Titular: BRYAN RIVERA GREY
- NIF/CIF: 42303973G
- Domicilio: Calle Ramon Turro 54, piso 1, puerta 2, Palafolls, Barcelona, España
- Contacto privacidad: privacidad@kombax.es
- DPO, si procede: No designado en la fase piloto actual. A fecha de esta versión no se aprecia obligación de designación conforme al art. 37 RGPD y al art. 34 LOPDGDD por la escala y naturaleza actuales del tratamiento; esta conclusión se revisará antes de ampliar sustancialmente la escala, el seguimiento sistemático o el tratamiento de categorías especiales.

## Actividades

### A. Cuenta y autenticación
- Datos: email, identificadores internos, eventos de acceso y seguridad.
- Finalidad: alta, autenticación, recuperación de contraseña, seguridad de cuenta y prevención de abuso.
- Base propuesta: ejecución del servicio; interés legítimo en seguridad y prevención de fraude; obligación legal cuando sea aplicable.
- Conservación: mientras exista la cuenta y, para logs de seguridad, durante el periodo documentado de seguridad/cumplimiento.

### B. Gestión privada de club
- Datos: identificación, datos deportivos, asistencia, roles, comunicaciones del club y, cuando proceda, información económica/administrativa.
- Finalidad: prestación del servicio de gestión del club y relación club-usuario.
- Roles RGPD: el club actúa con carácter general como responsable de su gestión privada y KOMBAX como encargado conforme al art. 28 RGPD. KOMBAX actúa como responsable independiente para cuenta global, seguridad, Social, Showcase, moderación, verificación y obligaciones propias.
- Base: relación contractual/servicio y obligaciones legales del club/responsable cuando proceda.

### C. KOMBAX Social
- Datos: identidad pública, avatar/banner, bio, disciplina, afiliaciones visibles, publicaciones, comentarios, likes, bloqueos y relaciones privadas.
- Finalidad: red social deportiva y profesional opcional.
- Base propuesta: activación voluntaria y prestación del servicio Social; consentimientos específicos solo donde el tratamiento dependa jurídicamente de consentimiento.
- Menores: control adicional de producto; autorización adulta para menores de 18 y chat privado bloqueado <18.

### D. Showcase
- Datos: identidad profesional, publicaciones de productos/servicios, guardados e interés/contacto.
- Finalidad: exposición y contacto profesional dentro del ecosistema KOMBAX.
- Base propuesta: ejecución del servicio solicitado y gestión de la relación profesional.

### E. Moderación y Child Safety
- Datos: reportes, bloqueos, snapshots mínimos de contenido denunciado, decisiones, metadatos y auditoría.
- Finalidad: seguridad, cumplimiento de normas, prevención de abuso/fraude y protección de menores.
- Base propuesta: interés legítimo documentado en seguridad y protección de usuarios; obligaciones legales cuando resulten aplicables.
- Acceso: mínimo privilegio; mensaje denunciado no habilita acceso general a conversaciones privadas.

### F. Verificación profesional
- Datos: documentos aportados por Club/Federación/Marca/Competidor y metadatos de revisión.
- Finalidad: verificar la legitimidad del perfil y reducir suplantación/fraude.
- Base propuesta: prestación del servicio solicitado e interés legítimo en integridad de la plataforma; revisar categorías especiales antes de aceptar documentación.
- Almacenamiento: privado; acceso separado de Moderación.

### G. Notificaciones
- Datos: token push, usuario/club, categoría y estado de entrega.
- Finalidad: comunicaciones operativas de Mi club y avisos de plataforma.
- Regla de producto: los push operativos del Club no son configurables por categoría dentro de KOMBAX; el permiso del sistema operativo sigue siendo el control global del dispositivo.
- Privacidad: contenido sensible, especialmente importes financieros, no debe aparecer en texto de bloqueo.

### H. Soporte, incidentes y seguridad
- Datos: telemetría sanitizada, códigos de error, build, contexto técnico limitado y auditoría privilegiada.
- Finalidad: disponibilidad, diagnóstico, respuesta a incidentes y seguridad.
- Base propuesta: ejecución del servicio e interés legítimo en seguridad.

## Proveedores técnicos actualmente previstos
La versión final de la política debe reflejar contratos, DPA, regiones y transferencias reales antes de producción:
- Supabase (eu-west-1, Irlanda): base de datos, Auth, Storage y Edge Functions.
- Resend: correo transaccional configurado en Supabase Auth.
- Netlify: alojamiento/distribución web y PWA cuando se autorice el despliegue.
- Google Firebase Cloud Messaging: notificaciones push Android.
- Google Play: distribución Android cuando se publique.

No añadir proveedores que no estén realmente activos. Cualquier SDK futuro exige nueva revisión de privacidad, seguridad de menores y Data Safety.

## Derechos y supresión
KOMBAX dispone de solicitud de eliminación de cuenta, cola exclusiva Owner y ejecutor de supresión/anonimización. La ejecución debe borrar datos eliminables y conservar únicamente los registros que deban mantenerse por obligaciones legales, seguridad, prevención de fraude o integridad contable, con plazo y base documentados.

## Retenciones técnicas activas del piloto
- Papelera restaurable: 30 días.
- Notificaciones: 180 días.
- Historial de invitaciones: 30 días.
- Preinscripciones rechazadas: 365 días.
- Conversaciones eliminadas: 30 días.
- Challenges administrativos: 7 días.
- Sesiones administrativas: 30 días.
- Detalle deportivo sujeto a purga automatizada: 730 días.
- Registros económicos, contables, fraude, seguridad y cumplimiento: conservar solo cuando exista una base y un plazo documentados; no entran en una purga indiscriminada.

## Pendientes de gobernanza antes de producción abierta
1. Formalizar el acuerdo de encargo/DPA con cada club real antes de importar sus datos.
2. Mantener verificados DPA, subencargados, regiones y garantías de transferencias de los proveedores activos.
3. Reevaluar necesidad de EIPD y DPD si aumenta sustancialmente la escala, el seguimiento sistemático o el tratamiento de categorías especiales.
4. Revisar el registro tras cada cambio material de Social, menores, moderación, Analytics o proveedor.

Versión 1.0 · build 20077 · 24/08/2026.
