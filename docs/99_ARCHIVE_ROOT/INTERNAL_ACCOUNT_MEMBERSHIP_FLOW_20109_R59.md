# KOMBAX 20.109 R59 — Informe interno de cuentas, alumnos, membresías y activación

## Objetivo
Este documento fija cómo KOMBAX separa **cuenta**, **perfil**, **membresía de club** y **ficha administrativa** para facilitar migraciones reales sin duplicar usuarios ni mezclar datos entre clubes.

## 1. Reglas maestras
1. **Una persona = una cuenta KOMBAX global** (`auth.users`).
2. Registrarse no convierte automáticamente a nadie en alumno. Sin membresía/perfil autorizado, la cuenta opera como **Espectador**.
3. **La ficha administrativa del alumno pertenece al club** y puede existir sin cuenta KOMBAX (`socios.perfil_id = NULL`).
4. La membresía se activa **por club y por ficha**. Una cuenta puede estar en varios clubes sin compartir datos entre ellos.
5. Finance, asistencia, documentos, licencias, grupos y comunicaciones se anclan a `club_id + socio_id`, no solo a `user_id`.
6. No se fusionan fichas por nombre. El email verificado ayuda a localizar; la vinculación definitiva exige invitación o aprobación segura.
7. El club nunca crea la contraseña del alumno. La persona verifica su correo y activa su propia cuenta.

## 2. Tipos de cuenta e identidades
### Cuenta base Espectador
Si no hay membresía activa ni perfil autorizado:
- puede ver Social, dar like, comentar y compartir;
- puede ver Showcase y pedir información de productos mediante conversación de producto;
- puede contactar clubes como futuro alumno;
- puede solicitar perfiles adicionales (Competidor, Profesional, Marca, Club, Federación, Media/Creador, etc.);
- no puede publicar en Social ni Showcase;
- no tiene Mi Red ni chat Social general;
- no ve Mi Club/Mis clubes.

### Perfiles adicionales
Una misma cuenta puede añadir identidades verificadas sin crear otra cuenta Auth: Competidor, Profesional, Marca, Club, Federación, Media/Creador u otras futuras.

### Membresía de alumno
Es independiente por club. Activar Club A no activa Club B. Dar de baja Club A no afecta Club B ni otros perfiles.

## 3. Estados administrativos y de acceso
Son dos ejes distintos:

**Estado del alumno en el club**: `prealta / activo / suspendido / baja`.

**Estado de acceso KOMBAX**: `sin_activar / invitacion_pendiente / vinculacion_pendiente / activo`.

En interfaz R59, una ficha `sin_activar` puede mostrarse como:
- **Falta email**: alumno 16+ histórico/migrado sin correo;
- **Tutor pendiente**: menor de 16 sin tutor digital activado;
- **Sin activar**: hay datos suficientes, pero aún no se ha iniciado la activación.

## 4. Flujo A — Alta autónoma de alumno 16+
1. El club crea una preinscripción.
2. Son obligatorios: nombre, apellidos, fecha de nacimiento, teléfono y **email propio del alumno**.
3. R59 valida que tenga **16 años o más**, manteniendo la regla KOMBAX de alumno autónomo 16+.
4. Al aprobar la plaza se crea o reutiliza la ficha administrativa exacta.
5. Se genera una invitación personal ligada a `club_id + socio_id + email`.
6. El sistema intenta enviar el email de activación. Si el envío falla, la ficha y la invitación permanecen guardadas para reenvío.
7. El alumno abre KOMBAX, verifica el mismo correo y acepta la invitación.
8. La cuenta se vincula a la ficha existente; no se crea otro alumno y se conserva todo el histórico.

**Regla 16–17:** el alumno puede tener cuenta y membresía propia desde los 16 años. Esto no modifica las protecciones de KOMBAX Social para menores de 18 ya existentes: cuando una función Social requiera consentimiento del tutor, deberá existir/validarse esa relación de tutor antes de habilitarla.

## 5. Flujo B — Alumno histórico/migrado sin email
1. Excel/agente IA crea la ficha directamente en `socios` sin crear Auth.
2. El club puede gestionar cuotas, pagos, grupos, asistencia, documentos y licencias desde el primer día.
3. El acceso aparece como **Falta email**.
4. Cuando el club obtiene el correo, usa `Activar KOMBAX`.
5. Se crea una invitación ligada a esa ficha exacta.
6. Al aceptarla se vincula la cuenta sin duplicar el alumno.

La falta de email **no bloquea migraciones históricas**. Solo las altas nuevas por preinscripción lo exigen.

## 6. Flujo C — Menor de 16
1. El menor de 16 tiene su propia ficha administrativa.
2. No necesita email propio.
3. En una alta nueva para menor de 16 se exige fecha de nacimiento, nombre del tutor y **email del tutor responsable**.
4. La invitación se envía al tutor.
5. El tutor crea/usa su cuenta KOMBAX y acepta la invitación.
6. R59 crea la relación `tutor -> menor -> club`; no asigna la cuenta adulta como si fuera la identidad del menor.
7. Una cuenta tutor puede gestionar varios menores y varios clubes, manteniendo cada membresía separada.

## 7. Flujo D — La persona ya era Espectador y el club ya tenía/importó su ficha
1. La cuenta KOMBAX tiene un email verificado.
2. KOMBAX puede proponer fichas pendientes del mismo email sin fusionarlas automáticamente.
3. El usuario solicita vincular una ficha.
4. El club recibe la solicitud en **Alumnos > Solicitudes de vinculación**.
5. Dirección/Secretaría aprueba o rechaza.
6. Al aprobar se vuelve a verificar email, estado de la ficha y ausencia de otra membresía de alumno de esa cuenta en el mismo club.
7. Se vincula la ficha existente y se conserva todo su historial.

## 7.1 Fichas históricas sin fecha de nacimiento
Una ficha migrada puede conservarse y gestionarse aunque le falten datos, pero **no puede activarse digitalmente hasta disponer de fecha de nacimiento**. KOMBAX necesita ese dato para decidir de forma segura si corresponde acceso autónomo (16+) o acceso mediante tutor (<16). Una edad desconocida nunca se tratará automáticamente como acceso autónomo.

## 8. Multiclub
Ejemplo: una misma cuenta puede tener:
- Alumno · Urban Warriors (`socio_id A`)
- Alumno · Club B (`socio_id B`)
- Competidor
- Media/Creador

Cada `socio_id` conserva cuotas, licencias, documentos, grupos y notificaciones del club correspondiente. No se mezclan datos entre organizaciones.

Dentro de un mismo club R59 bloquea que una misma cuenta quede asociada a dos fichas de alumno distintas. En clubes diferentes sí está permitido.

## 9. Baja y retorno a Espectador
La baja/suspensión revoca únicamente esa membresía. La cuenta KOMBAX global permanece.
- Si mantiene otro club o perfil autorizado, sigue operando con esos contextos.
- Si no queda ninguna membresía/perfil autorizado, vuelve funcionalmente a **Espectador**.
- El histórico del club se conserva y no se transfiere a otras organizaciones.

## 10. Deduplificación y seguridad
- Emails normalizados a minúsculas/trim en los flujos de activación.
- Supabase Auth mantiene la identidad global.
- No se crean usuarios Auth durante importaciones.
- Una invitación personal queda ligada a una ficha concreta (`socio_id`).
- No se vincula por nombre.
- Si una nueva preinscripción autónoma 16+ usa un email ya presente como alumno del club, se obliga a trabajar sobre la ficha existente.
- Si una posible ficha histórica coincide por nombre + fecha de nacimiento pero todavía no tiene email, R59 detiene la creación automática para revisión manual en vez de duplicarla.
- Las vinculaciones usan locks y controles para evitar carreras simultáneas.

## 11. Impacto para migraciones de clubes
El club no necesita tener previamente a todos sus alumnos registrados en KOMBAX. Puede importar primero toda su base y activar cuentas progresivamente. Esto reduce fricción de onboarding y mantiene la gestión administrativa disponible desde el inicio.

Recomendación de importación:
- conservar identificador externo del club cuando exista;
- importar email si está disponible;
- no inventar emails ni cuentas Auth;
- para menores, conservar datos del tutor si existen;
- marcar incidencias de identidad para revisión humana en lugar de fusionar automáticamente.

## 12. Implementación R59
Migración principal: `supabase/migrations/250_kombax_enrollment_activation_accounts_r59.sql`.

Cambios principales:
- email de acceso obligatorio en preinscripciones nuevas;
- alumno autónomo 16+; menor de 16 mediante tutor para membresía;
- aprobación de preinscripción prepara invitación de la ficha existente;
- importados históricos pueden seguir sin email;
- estados visuales Falta email / Tutor pendiente;
- aprobación/rechazo de reclamaciones de membresía;
- backend de aceptación actualizado a R59;
- conservación de los permisos Espectador y del modelo multiclub de R58.

## 13. QA obligatorio antes de producción
1. Alumno 16+ nuevo -> preinscripción -> aprobación -> email -> activación.
2. Alumno 16+ migrado sin email -> gestión administrativa -> añadir email -> activar.
3. Menor de 16 -> preinscripción -> tutor -> activación -> acceso familiar.
4. Tutor con dos hijos.
5. Persona en dos clubes, activados en momentos distintos.
6. Baja en un club sin afectar al otro.
7. Espectador -> ficha importada -> solicitud -> aprobar/rechazar.
8. Intento de duplicado por mismo email en el mismo club.
9. Doble importación/reintento simultáneo.
10. RLS: Finance/documentos/notificaciones no cruzan clubes.
11. Espectador sigue sin publicar en Social/Showcase y sin Mi Red/Mi Club.

## Estado de release
R59 es una base de QA. No considerar producción lista hasta aplicar/revisar migración 250 en Supabase, ejecutar QA autenticado multiclub/RLS y completar firma Android/Google Play y validaciones de despliegue correspondientes.
