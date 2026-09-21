# Urban Warriors RC13 · implementación del MVP Freeze

## Identificación

- Base recibida: `Urban_Warriors_RC12_build_20016_complete`
- Candidata creada: **2.0.0-rc.13**
- Build / Android `versionCode`: **20017**
- Objetivo: cerrar el alcance funcional acordado antes de la fase formal de pruebas.
- Estado: **implementación local completada; pendiente de certificar Supabase real, navegador real y APK física antes del freeze definitivo**.

RC12 no se sobrescribe. RC13 es una candidata nueva y reversible.

---

## 1. Reparación responsive PC / móvil / APK

Se añadió una guardia explícita de escritorio a partir de 821 px para impedir que reglas destinadas a móvil contaminen la experiencia PC.

Se fuerzan en escritorio, entre otros:

- sidebar estable y visible;
- ausencia de bottom-nav y scrim móvil;
- topbar y márgenes de escritorio;
- formularios en dos columnas;
- tablas con semántica de tabla, no tarjetas móviles;
- modales centrados y dimensionados para PC;
- fondo de marca alineado con sidebar de 250/280 px según ancho.

Las reglas móviles existentes siguen limitadas a sus breakpoints y las nuevas vistas de perfil/eventos incluyen adaptación específica en pantallas pequeñas.

**Criterio:** mismas funciones en PC, web móvil y APK; cambia la presentación, no la capacidad funcional.

---

## 2. Finanzas y recibos

RC13 conserva el motor ya preparado en RC12 y refuerza su certificación, sin inventar una segunda contabilidad.

Fuente de verdad:

- `cuotas`: cargos;
- `pagos`: cobros comunicados/validados;
- `recibos_cuota`: recibos;
- `origen`: `cuota`, `material`, `otro`;
- `v_finanzas_detalle`: una fila por cargo con saldo derivado;
- métricas: derivadas del mismo conjunto, no almacenadas en paralelo.

La migración **031** clasifica recibos por origen/concepto, amplía el estado de cuenta y audita:

- pagados sin recibo;
- material pagado sin recibo;
- recibos de material mal identificados;
- recibos emitidos antes de pago completo;
- duplicidad de recibos por cargo.

Se añadió además una prueba matemática ejecutable sobre el frontend para verificar que:

`Cuotas + Material + Otros = Total generado`

sin inflar cobros por sobrepagos y manteniendo pendiente/vencido bajo el mismo conjunto filtrado.

**Importante:** el usuario confirmó que 031 no se ejecutó todavía en Supabase real. RC13 no se considera certificada hasta completar el runbook SQL.

---

## 3. Likes privados en Comunidad

Implementación mínima del MVP:

- corazón + contador;
- dar like;
- quitar like;
- un like máximo por usuario/publicación;
- contador consistente mediante trigger;
- aislamiento por club.

### Privacidad

La identidad de quienes dan like **no se expone**.

La tabla `comunidad_likes` solo concede al cliente lectura de la fila propia. La interfaz únicamente conoce:

- si el usuario actual ha dado like;
- número total de likes.

No existe endpoint/frontend para recuperar una lista de personas que dieron like.

No se añadieron comentarios, seguidores, ranking ni chat.

---

## 4. Perfil deportivo / social

Se creó `perfiles_deportivos`, separado del perfil administrativo.

### Datos deportivos compartibles

- foto deportiva;
- apodo;
- presentación;
- experiencia;
- guardia;
- técnica favorita;
- especialidad;
- categoría competitiva;
- competiciones/logros;
- objetivos.

Disciplina, grado y grupo se derivan de las matrículas oficiales del club y no los escribe libremente el alumno.

### Datos expresamente excluidos

La RPC pública deportiva no devuelve:

- teléfono;
- email;
- dirección;
- fecha de nacimiento completa;
- documentos;
- datos financieros;
- datos bancarios;
- información familiar/administrativa.

### Menores y tutores

El perfil se vincula a `socio_id`, no únicamente a una cuenta. El propio alumno o un tutor vinculado puede editarlo.

### Privacidad y moderación independientes

Se separaron dos conceptos para evitar un fallo de diseño:

- `visible`: decisión del alumno/tutor de compartir el perfil;
- `moderacion_oculta`: bloqueo aplicado por moderación.

Un usuario no puede levantar por sí mismo un bloqueo de moderación. A la vez, un moderador no puede convertir en público un perfil que el alumno/tutor decidió mantener privado.

Los perfiles son accesibles únicamente a miembros autenticados del mismo club. La tabla no concede SELECT directo al cliente; la lectura se realiza mediante una RPC de datos deportivos seguros.

La foto usa un bucket privado independiente `sports-profile-media`.

---

## 5. Navegación entre perfiles

Comunidad integra:

- autor enlazable a su perfil deportivo cuando procede;
- directorio sencillo de miembros con perfil compartido;
- foto/apodo/nombre + información deportiva oficial.

No se ha convertido Urban Warriors en una red social abierta.

---

## 6. Eventos y competiciones

Se implementó el módulo `Eventos` con tres entidades:

1. `eventos_competicion`
2. `evento_participantes`
3. `evento_combates`

### Evento

Incluye:

- nombre y descripción;
- disciplina;
- fecha/horario/lugar;
- organizador;
- fecha límite de inscripción;
- estado;
- requisitos de edad/peso/categoría/grado;
- documentación;
- autorización;
- cuota;
- indicaciones.

Estados: `borrador`, `abierto`, `cerrado`, `finalizado`, `cancelado`.

### Inscritos internos

Familia/alumno puede solicitar inscripción de un socio vinculado cuando el evento está abierto y dentro del plazo.

El equipo autorizado puede completar la lista después del cierre de inscripción, pero no en un evento finalizado o cancelado.

Estados: `solicitado`, `confirmado`, `rechazado`, `baja`.

### Participantes externos

No necesitan Urban Warriors ni cuenta.

El organizador puede registrar únicamente los datos deportivos necesarios: nombre, club, disciplina, categoría, peso, grado, edad deportiva y observaciones. No se han añadido teléfono, email, dirección ni documento de identidad.

### Combates

Emparejamientos manuales:

- participante A / B;
- disciplina;
- categoría;
- tatami/ring;
- orden;
- hora;
- estado;
- resultado;
- ganador;
- observaciones internas.

Solo participantes confirmados pueden formar un combate. No se puede invalidar un participante mientras tenga un combate activo. El ganador debe ser A o B.

No se implementaron brackets, sorteos ni cabezas de serie automáticas.

---

## 7. Privacidad de eventos

La tabla de eventos sí puede consultarse bajo RLS del club.

Las tablas de participantes y combates **no tienen SELECT directo para `authenticated`**. Se consumen mediante RPCs seguras:

- el equipo ve la información operativa necesaria;
- miembros ordinarios ven participantes confirmados;
- familia/alumno conserva acceso a sus propias solicitudes;
- peso, edad y observaciones de terceros se enmascaran;
- observaciones internas de combate solo se muestran al equipo.

---

## 8. Gateway y contrato backend

Todas las escrituras nuevas pasan por `app_mutate_v160`.

032 añade:

- `perfil_deportivo.guardar`
- `perfil_deportivo.foto`
- `perfil_deportivo.moderar`
- `comunidad.like`

033 añade:

- `evento.guardar`
- `evento.estado`
- `evento.participante.externo`
- `evento.inscripcion.solicitar`
- `evento.inscripcion.estado`
- `evento.inscripcion.baja`
- `evento.combate.guardar`
- `evento.combate.eliminar`

Los wrappers delegan cualquier operación anterior al gateway previo y extienden también `app_runtime_contract_v160`.

### Puerta adicional RC13

El frontend RC13 exige explícitamente las 12 operaciones nuevas en el contrato backend. Si se despliega RC13 contra un Supabase que no tenga 032/033 completas, el contrato falla antes de permitir una operación normal, en vez de descubrir la incompatibilidad durante el uso.

---

## 9. Correcciones defensivas encontradas durante la implementación

Durante la auditoría se corrigieron además defectos que podían generar problemas reales:

- un moderador ya no obtiene pseudo-perfiles de todos los socios que nunca crearon perfil deportivo;
- privacidad voluntaria y moderación ya no compiten por el mismo booleano;
- las FKs `ON DELETE SET NULL` nuevas no intentan poner `club_id` a NULL en claves compuestas;
- el alta de un alumno por el equipo en Eventos ya no depende de un `setTimeout` entre dos modales;
- botones de autoinscripción se muestran únicamente en el portal familia/alumno;
- el equipo puede completar inscritos con inscripción cerrada, pero nunca en evento finalizado/cancelado;
- edición de evento conserva el estado seleccionado;
- se valida que un participante no quede no-confirmado si mantiene un combate activo.

---

## 10. Tests añadidos a RC13

- `test-rc13-finance-math.mjs`
- `test-rc13-backend-gate.mjs`
- `test-rc13-social-profiles.mjs`
- `test-rc13-events.mjs`
- `test-rc13-responsive.mjs`
- `test-rc13-sql-chain.mjs`

Cubren, entre otras cosas:

- matemáticas financieras;
- operaciones requeridas por el contrato;
- privacidad de likes;
- perfil deportivo sin PII administrativa;
- tutor/menor;
- moderación;
- RLS/lecturas seguras;
- participantes externos;
- inscripciones;
- combates;
- breakpoints PC/móvil;
- cadena 031 → 032 → 033;
- transacciones y delimitadores SQL;
- rollback del gateway y del contrato runtime.

Las regresiones históricas RC4–RC12 permanecen dentro de `npm test`.

---

## 11. Puertas todavía manuales y obligatorias

Un test estático no sustituye un entorno real. Antes de etiquetar `FINAL FREEZE` todavía se exige:

1. certificar 023–030 en el Supabase real;
2. ejecutar y verificar 031;
3. ejecutar y verificar 032;
4. ejecutar y verificar 033;
5. prueba CRUD/RLS con roles reales;
6. prueba PC real;
7. prueba web móvil real;
8. build Android;
9. APK firmada en dispositivo físico;
10. push/Netlify únicamente después de lo anterior.

No se debe afirmar “MVP congelado” hasta superar estas puertas.
