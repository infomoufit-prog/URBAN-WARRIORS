# Política de Privacidad global KOMBAX — versión piloto 20077

> Versión preparada para el piloto controlado de dos clubes. Debe revisarse de nuevo antes de una apertura pública o cambio material de proveedores, escala o categorías de datos.

## 1. Responsable del tratamiento
**Responsable:** BRYAN RIVERA GREY
**NIF:** 42303973G
**Domicilio:** Calle Ramon Turro 54, piso 1, puerta 2, Palafolls, Barcelona, España
**Email de privacidad:** privacidad@kombax.es
**DPO/DPD:** No designado en la fase piloto actual. A fecha de esta versión no se aprecia obligación de designación conforme al art. 37 RGPD y al art. 34 LOPDGDD por la escala y naturaleza actuales del tratamiento; esta conclusión se revisará antes de ampliar sustancialmente la escala, el seguimiento sistemático o el tratamiento de categorías especiales.

## 2. Alcance
Esta política cubre la plataforma KOMBAX, incluyendo autenticación y cuenta, KOMBAX Social, KOMBAX Showcase, administración de plataforma, moderación, verificación profesional, notificaciones y soporte. La gestión privada que cada club realice como responsable de sus propios datos podrá estar sujeta además a la información de privacidad específica del club.

## 3. Datos tratados
- Identificación y acceso: email, identificadores internos, credenciales gestionadas por el proveedor de autenticación y registros de seguridad.
- Perfil KOMBAX: nombre público, avatar/banner, bio, disciplina, afiliaciones verificadas y publicaciones que el usuario decida hacer públicas.
- Mi club: datos administrativos, deportivos, económicos y documentales según rol y relación con el club.
- Social y moderación: publicaciones, comentarios, likes, bloqueos, denuncias y, solo cuando se denuncia un mensaje privado, la evidencia mínima vinculada a ese mensaje.
- Verificación profesional: documentación aportada para verificar perfiles, alojada en almacenamiento privado.
- Dispositivo: token push, datos técnicos mínimos y telemetría de incidentes sanitizada.

## 4. Finalidades y bases jurídicas
- Prestación/mantenimiento del servicio y medidas precontractuales: relación contractual o precontractual cuando corresponda.
- Seguridad, prevención de fraude, abuso y moderación: interés legítimo sujeto a ponderación y documentación, además de obligaciones legales cuando proceda.
- Cumplimiento de obligaciones legales: conservación o tratamiento cuando una norma aplicable lo exija, incluida la documentación económico-contable que corresponda.
- Consentimiento: solo para tratamientos cuya base jurídica sea el consentimiento, mediante acción afirmativa, específica e informada y con posibilidad de retirada cuando resulte aplicable.
- KOMBAX Social es opcional y la protección de menores utiliza controles de producto más restrictivos que el mínimo legal: autorización adulta <18 y chat privado bloqueado <18.

Para el piloto, la base y el rol de cada actividad se documentan en el registro de tratamientos y en el acuerdo de encargo con cada club. Cualquier ampliación material requiere nueva revisión jurídica.

## 5. Menores
Mi club puede incluir menores gestionados con tutor. KOMBAX Social exige autorización de un tutor vinculado para perfiles personales menores de 18 años y mantiene el contacto privado deshabilitado para menores de 18 años. El tutor puede revocar la autorización Social.

## 6. Destinatarios y encargados
Arquitectura técnica del piloto:
- Supabase (proyecto principal en eu-west-1, Irlanda): base de datos, Auth, Storage y Edge Functions.
- Resend: correo transaccional de Supabase Auth.
- Netlify: alojamiento/distribución web y PWA cuando se autorice el despliegue.
- Google Firebase Cloud Messaging: notificaciones push Android.
- Google Play: distribución Android cuando se publique.

Para la gestión privada de club, el club actúa con carácter general como responsable y KOMBAX como encargado conforme a instrucciones documentadas y acuerdo del artículo 28 RGPD. KOMBAX es responsable independiente de la cuenta global, seguridad de plataforma, Social, Showcase, moderación, verificación y obligaciones propias. Los DPA, subencargados, regiones y garantías de transferencias se revisan cuando cambie un proveedor o la escala.

## 7. Conservación
Los datos se conservan mientras exista la cuenta o relación necesaria y durante los plazos legales aplicables. La política automatizada del piloto aplica: papelera 30 días; notificaciones 180 días; historial de invitaciones 30 días; preinscripciones rechazadas 365 días; conversaciones eliminadas 30 días; challenges admin 7 días; sesiones admin 30 días; detalle deportivo automatizado 730 días. Las trazas económico-contables, de seguridad o cumplimiento con obligación de conservación no se purgan indiscriminadamente y requieren base y plazo documentados.

## 8. Derechos
Acceso, rectificación, supresión, oposición, limitación y portabilidad cuando proceda. KOMBAX incorpora solicitud de eliminación de cuenta. Contacto: privacidad@kombax.es. Derecho a reclamar ante la AEPD u otra autoridad competente.

## 9. Seguridad
Acceso Owner mediante cuenta autorizada, contraseña reciente y sesión privilegiada temporal; OTP adicional para operaciones críticas/destructivas. RLS, almacenamiento privado, separación de roles, Modo Soporte temporal auditado, auditoría privilegiada y procedimientos de respuesta a incidentes.

## 10. Cambios
Versión 1.0.0 · build 20077 · 24/08/2026.
