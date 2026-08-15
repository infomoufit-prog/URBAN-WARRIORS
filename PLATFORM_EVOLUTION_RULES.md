# Urban Warriors · Reglas permanentes de evolución de producto

Estado: **contrato de arquitectura para RC13 build 20020 y posteriores**.

## 1. Alcance actual

Urban Warriors sigue siendo, en esta fase, una aplicación/entorno único de validación del MVP del gimnasio Urban Warriors. **No se despliega todavía una plataforma multiclub visible, no se cambia el nombre de la aplicación y no se crea un selector general de clubes.**

La obligación actual es distinta: toda decisión nueva debe evitar bloquear una evolución posterior hacia una plataforma general. Urban Warriors será el primer club/tenant cuando esa capa exista, no una excepción de negocio.

## 2. Regla de evolución multiclub

- No introducir condiciones de negocio del tipo `club.nombre === 'Urban Warriors'`.
- No usar el UUID del club como excepción funcional. El ID de Urban Warriors puede existir en configuración del MVP, nunca como permiso especial.
- Los recursos privados de gestión mantienen `club_id`, RLS y gateway.
- La futura generalización debe poder añadir clubes sin duplicar el frontend ni bifurcar la app.
- El branding futuro será configuración/datos, no un fork por club.

## 3. Gestión privada e identidad pública son capas distintas

Nunca construir un perfil público leyendo directamente el expediente administrativo.

Datos administrativos que no se publican automáticamente: email, teléfono privado, domicilio, CIF/documentación, fecha completa de nacimiento, emergencias, familia/tutores, finanzas y documentos.

Los datos públicos deben existir en una estructura creada expresamente para publicación y ser voluntarios/moderables.

## 4. Perfil público de club

RC13 build 20020 valida el modelo con Urban Warriors mediante `perfiles_club_publicos`.

- El nombre del club dentro de Comunidad interna es el punto de navegación al perfil público.
- El logo es visual; no es el mecanismo obligatorio de navegación.
- La misma ficha/modelo será reutilizable más adelante en Comunidad General.
- El perfil público usa identificador estable (`slug`) separado del nombre visible.
- Edición: Gestor/Dirección o Coordinación autorizada del propio club.

## 5. Identidad pública normalizada

No crear una tabla monstruosa con todos los campos de alumno, club, federación, marca y tienda.

Cada dominio conserva su modelo propio y una capa común entrega al consumidor una forma normalizada: identificador público, tipo, referencia, nombre, subtítulo, slug y media.

RC13 valida dos fuentes: `club` y `miembro/perfil deportivo`. Futuras capas podrán añadir `competidor`, `federacion`, `marca` y `tienda`.

## 6. Comunidad del Club y Social Community / Comunidad General son ámbitos distintos

La **Comunidad del Club** actual de Urban Warriors es interna al club. Sus publicaciones **no se convierten automáticamente en contenido global**.

La futura **Social Community / Comunidad General** será un servicio social opcional, con alta propia, normas propias, privacidad y moderación independientes.

Tener cuenta del club no equivale a tener perfil en Social Community / Comunidad General.

Tampoco se considera aceptada automáticamente la normativa social por crear una cuenta del club. Para publicar contenido generado por usuarios, las normas de la Comunidad correspondiente deben mostrarse y aceptarse expresamente; la retirada de esa aceptación bloquea nuevas publicaciones sin eliminar la cuenta administrativa.

## 7. Edad y cuentas

### Autorregistro como alumno del club

- Desde **16 años cumplidos**: el alumno puede crear su propia cuenta y enviar su preinscripción/solicitud deportiva mediante el flujo actual.
- Menor de 16: no crea una cuenta de alumno independiente; se mantiene el flujo mediante club y/o padre, madre o tutor.
- El límite se valida en backend y también se explica/valida en frontend.

### Social Community / Comunidad General

- Umbral social configurado en backend por club mediante `edad_min_comunidad_general`, con **suelo de producto de 14 años cumplidos**, siempre calculados con fecha de nacimiento verificada por el club.
- No se acepta una edad autodeclarada para saltar el control.
- Cumplir la edad solo habilita la opción: la activación social es voluntaria.
- Padre/madre/tutor no puede activar Social Community / Comunidad General en esta fase.
- En el MVP actual los menores de 16 no disponen de autorregistro autónomo; por ello la arquitectura 14+ queda preparada sin inventar ahora un mecanismo de credenciales adicional para 14–15. Antes de habilitar una experiencia social real para 14–15 en distribución pública se deberá cerrar expresamente el modelo de credenciales, control adulto/público objetivo y las obligaciones vigentes de la tienda/aplicación.

## 8. Seguridad de contenido generado por usuarios

La experiencia social debe incluir desde su base:

- denunciar publicación;
- denunciar perfil;
- bloquear/desbloquear perfil;
- revisión por equipo autorizado;
- ocultar contenido denunciado;
- resolución/descartado trazable de denuncias;
- suspensión/reactivación del acceso social con motivo y auditoría;
- separación entre moderación y preferencias de privacidad.

Bloquear un perfil social no puede bloquear comunicaciones administrativas, avisos de seguridad ni obligaciones del club.

## 9. Notificaciones operativas

Las notificaciones informativas y las tareas que requieren acción tienen semántica diferente.

- Informativas: lectura individual, por grupo y masiva.
- Requiere acción: no se puede limpiar mediante acciones masivas.
- La accionabilidad se calcula con el estado vivo del objeto relacionado, no solo con `tipo`.
- Una tarea accionable se revisa mediante una acción explícita que deja auditoría y abre su ruta funcional.
- El diseño debe soportar alto volumen de Dirección/Secretaría/Economía/otros roles de equipo, especialmente en APK móvil.

## 10. Compatibilidad de actualización

La instalación actual de Urban Warriors es el piloto real del MVP y debe poder evolucionar a la misma aplicación futura.

- conservar identidad Android de la app;
- conservar clave/firma de actualización;
- aumentar `versionCode` de forma monótona;
- migraciones de datos hacia delante, no reinicios destructivos;
- no obligar a desinstalar para actualizar;
- probar cada candidato instalándolo encima de la build anterior cuando sea posible.

## 11. Orden obligatorio de cualquier cambio futuro

**concepto → alcance → privacidad → permisos → tenant/aislamiento → modelo de datos → gateway/RPC → frontend → responsive → Android → tests → Supabase real → dispositivo físico → freeze → deploy**

No desplegar una migración nueva solo porque el código compila. Cada migración debe tener preflight, verificación y rollback/retorno documentado.

## 12. Fuera del freeze actual

No forman parte del cierre RC13 build 20020:

- entorno multiclub visible completo;
- nuevo nombre/branding de plataforma general;
- selector global de clubes;
- feed de Social Community / Comunidad General;
- seguidores/amistades/chat;
- competidor independiente funcional;
- federaciones funcionales;
- marcas/tiendas funcionales;
- marketplace/patrocinios;
- brackets automáticos multiclub.

Se prepara la arquitectura; no se simula que estas funciones ya existen.
