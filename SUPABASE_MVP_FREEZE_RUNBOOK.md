# Urban Warriors RC13 · Runbook Supabase MVP Freeze

## Regla de oro

Ejecutar en el **SQL Editor del proyecto correcto** con privilegios de propietario/postgres y con copia de seguridad previa.

**STOP inmediato** ante cualquier `FALLO`, excepción o número de incidencias distinto de cero. No continuar “a ver si el siguiente lo arregla”.

Las migraciones nuevas no deben probarse por primera vez directamente contra producción si existe posibilidad de usar una rama/proyecto staging.

---

## Paso 0 · Backup y proyecto

Antes de SQL:

- confirmar URL/proyecto Supabase;
- snapshot/backup disponible;
- anotar fecha/hora;
- no desplegar Netlify RC13 todavía;
- no generar APK final todavía.

---

## Paso 1 · Certificar la base 023–030

Ejecutar primero:

`supabase/verification/final_audit_023_030.sql`

Resultado requerido: **10/10 OK**.

### Si 029 o 030 aparecen pendientes

No saltar directamente a 031.

Orden:

1. `supabase/verification/preflight_029_video.sql`
2. `supabase/migrations/029_community_video_covers.sql`
3. `supabase/verification/verify_029_video.sql`
4. `supabase/verification/preflight_030_multiclub.sql`
5. `supabase/migrations/030_multiclub_rls_performance.sql`
6. `supabase/verification/verify_030_multiclub.sql`
7. repetir `supabase/verification/final_audit_023_030.sql`

Solo continuar cuando el audit final vuelva a dar 10/10 OK.

---

## Paso 2 · Finanzas 031

El usuario confirmó que esta migración no se había aplicado todavía al preparar RC13.

### 2A. Preflight

`supabase/verification/preflight_031_finance_receipts.sql`

Todas las filas deben ser `OK`, incluida **031 pendiente**.

Si “031 pendiente” devuelve `FALLO`, no volver a aplicar a ciegas: significa que existe al menos parte de 031 y debe diagnosticarse primero.

### 2B. Migración

`supabase/migrations/031_finance_receipts_breakdown.sql`

### 2C. Verificación

`supabase/verification/verify_031_finance_receipts.sql`

Requerido:

- todos los controles `OK`;
- `pagados_sin_recibo = 0` por origen;
- ningún duplicado;
- ningún recibo activo antes de pago completo.

### 2D. Prueba transaccional

`supabase/verification/test_031_receipts_transactional.sql`

Requerido: **7/7 OK**.

El script termina en `ROLLBACK`; no debe dejar cuotas, recibos ni notificaciones de prueba.

---

## Paso 3 · Perfiles deportivos + Likes 032

### 3A. Preflight

`supabase/verification/preflight_032_social.sql`

Requerido:

- todos los booleanos `true`;
- `controles_multiclub_030_no_ok = 0`;
- `controles_finanzas_no_ok = 0`.

### 3B. Migración

`supabase/migrations/032_social_profiles_likes.sql`

### 3C. Verificación

`supabase/verification/verify_032_social.sql`

Requerido:

- todos los booleanos `true`;
- `moderacion_sin_auditoria = 0`;
- `likes_descuadrados = 0`;
- `likes_duplicados = 0`.

### 3D. Prueba manual RLS

Con cuentas reales:

- alumno/tutor edita su socio;
- otro miembro del mismo club ve únicamente perfil compartido;
- otro miembro no ve perfil privado/moderado;
- un usuario de otro club no puede leerlo;
- foto privada respeta la misma regla;
- like se puede poner/quitar;
- no existe forma de listar identidades de likes desde el cliente.

---

## Paso 4 · Eventos / Competiciones 033

### 4A. Preflight

`supabase/verification/preflight_033_events.sql`

Todos los controles deben ser `true`.

### 4B. Migración

`supabase/migrations/033_events_competitions.sql`

### 4C. Verificación

`supabase/verification/verify_033_events.sql`

Requerido:

- todos los booleanos `true`;
- `combates_participantes_fuera_evento = 0`;
- `combates_con_participante_no_confirmado = 0`.

### 4D. Prueba manual RLS / negocio

- crear evento como Gestor/Coordinación/Secretaría/Monitor autorizado;
- confirmar que miembro ordinario no ve borradores;
- familia solicita inscripción de alumno vinculado;
- familia no puede solicitar por otro alumno;
- equipo confirma/rechaza;
- crear participante externo sin cuenta;
- usuario ordinario no ve peso/edad/observaciones privadas de terceros;
- crear combate con dos confirmados;
- impedir combate consigo mismo;
- impedir ganador fuera del combate;
- impedir rechazar/baja de participante con combate activo;
- aislamiento con un segundo club.

---

## Paso 5 · Contrato RC13

Después de 033, iniciar sesión con la web RC13.

RC13 exige estas operaciones en `app_runtime_contract_v160`:

- `perfil_deportivo.guardar`
- `perfil_deportivo.foto`
- `perfil_deportivo.moderar`
- `comunidad.like`
- `evento.guardar`
- `evento.estado`
- `evento.participante.externo`
- `evento.inscripcion.solicitar`
- `evento.inscripcion.estado`
- `evento.inscripcion.baja`
- `evento.combate.guardar`
- `evento.combate.eliminar`

Si falta una, el cliente debe rechazar el contrato backend. No continuar a APK/Netlify.

---

## Rollback

Solo en orden inverso y después de valorar los datos creados:

1. `supabase/rollbacks/033_events_competitions.sql`
2. `supabase/rollbacks/032_social_profiles_likes.sql`
3. `supabase/rollbacks/031_finance_receipts_breakdown.sql`

032/033 son conservadores: restauran gateway/contrato previo y dejan tablas/datos para evitar pérdida accidental. 031 retira automatismos y conserva clasificación histórica.

Un rollback de frontend debe acompañar al rollback de backend. No dejar RC13 apuntando a un backend RC12.
