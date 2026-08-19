# KOMBAX · reglas permanentes de evolución

Estado: **contrato de arquitectura vigente desde RC13 build 20025**.

## 1. Plataforma y tenant piloto

KOMBAX es la capa general. Urban Warriors es el tenant piloto y conserva por ahora la identidad Android `com.urbanwarriors.app` para permitir actualización sobre la instalación existente. Ningún permiso puede depender del nombre o UUID de Urban Warriors.

## 2. Dos puertas de entrada

- **Entrar mediante mi club**: búsqueda pública limitada, autenticación y acceso a un contexto para el que exista membresía activa.
- **Otros perfiles KOMBAX**: competidor, marca, federación, espectador o profesional vinculado. El modelo y la navegación están encajados, pero su alta, cobro y beneficios permanecen cerrados hasta una fase específica.

Elegir una tarjeta DEMO nunca crea membresía, suscripción ni entitlement.

## 3. Aislamiento multiclub

- Recursos operativos privados siempre delimitados por `club_id`, RLS y gateway.
- El cambio de club vuelve a validar membresía/capabilities y limpia caché y estado del tenant anterior.
- Auth, identidad pública, membresía, rol, suscripción y entitlement son conceptos distintos.
- La aplicación debe crecer a 100 clubes sin forks de frontend ni excepciones por club; esa capacidad solo se considera probada tras ensayos reales.

## 4. Branding y temas

Logo, banner y uno de los cuatro temas cerrados son configuración versionada del club. Los temas fijan tokens, tipografía y contraste; no permiten CSS arbitrario. Se puede cambiar de tema mediante publicación controlada y rollback de versión, sin duplicar assets ni lógica.

KOMBAX usa rojo, negro y blanco de forma propia; el entorno privado conserva la identidad elegida por cada club y el co-branding discreto KOMBAX.

## 5. Comunidad del Club y KOMBAX Social

Son dominios independientes. El contenido interno no se publica globalmente por defecto y tener cuenta del club no activa un perfil social.

KOMBAX Social Alpha exige alta voluntaria y normas propias. Incluye perfil público, feed, likes con identidad no expuesta, bloqueo, denuncia, moderación y una solicitud estructurada de contacto. No incluye seguidores, amistades, chat, mensajes, presencia ni intercambio automático de datos personales.

## 6. Privacidad y edad

El perfil público se construye desde campos expresamente publicables; nunca desde el expediente administrativo. Email, teléfono privado, domicilio, fecha completa de nacimiento, emergencias, familia, finanzas y documentos quedan fuera.

El backend calcula la edad desde una fuente verificada y bloquea el contacto si cualquiera de los perfiles personales es menor de 18 años. No basta una restricción visual. Cualquier futura experiencia social para menores exige un diseño legal, de credenciales y control adulto independiente.

## 7. Showcase no comercial

KOMBAX Showcase es un escaparate informativo de marcas y elementos publicados. No es tienda y no debe incorporar carrito, checkout, pedidos, cobros, stock, envío, devoluciones o marketplace sin una decisión de producto y arquitectura nueva.

## 8. Contenido y notificaciones

- Informativas: lectura individual, agrupada o masiva y contador persistente.
- Accionables: se resuelven con una acción explícita y estado vivo del objeto; una lectura masiva no las completa.
- Archivo/papelera: solo contenido permitido, recuperación durante 30 días y auditoría. Finanzas y recibos no se eliminan por este flujo.

## 9. Compatibilidad y secretos

- Mantener paquete y firma Android; incrementar `versionCode` de forma monótona.
- Migraciones hacia delante y reversión conservadora; nunca reinicios destructivos.
- JKS, contraseñas, Firebase real, `.env`, APK y AAB no entran en Git ni en el ZIP fuente.
- Probar cada candidata encima de la build anterior sin desinstalar.

## 10. Orden obligatorio

**concepto → alcance → privacidad → permisos → tenant → datos → RPC/RLS → frontend → responsive → Android → tests → Supabase real → E2E/dispositivo → carga → freeze → deploy**

Ningún informe puede afirmar una puerta externa que no haya sido ejecutada y conservado su resultado. Si una fase excede una sesión, se entrega el checkpoint verificable y se continúa en la siguiente, sin atajos ni parches que debiliten la arquitectura.

## 11. Fuera de build 20025

- alta/cobro y beneficios funcionales de perfiles directos;
- seguidores, amistades, chat o mensajería;
- comercio en Showcase;
- soporte de 100 clubes certificado por carga real;
- publicación Google Play o producción Netlify.
