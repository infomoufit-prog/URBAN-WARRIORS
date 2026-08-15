# Urban Warriors RC13 MVP · Informe de implementación y certificación local

## Identificación

- Base: `Urban_Warriors_RC12_build_20016_complete`
- Candidata: `2.0.0-rc.13`
- Build web / Android `versionCode`: `20017`
- Alcance: MVP freeze previo a pruebas reales.
- Producción: **no desplegada** desde este entorno.
- Supabase real: **no modificado** desde este entorno.

RC12 se conserva como referencia. RC13 es una candidata nueva y reversible.

## Alcance implementado

### 1. Responsive PC / web móvil / APK

- Guardia explícita de escritorio desde 821 px.
- Sidebar, tablas, formularios y modales recuperan comportamiento de escritorio.
- Bottom navigation y scrim móvil quedan fuera del layout de PC.
- Se conservan breakpoints y safe areas móviles.
- Mismas funciones en PC, web móvil y APK; solo cambia la presentación.

### 2. Finanzas

- Se preserva la fuente de verdad RC12 y la migración `031_finance_receipts_breakdown.sql` sin modificarla.
- Se extrajo la matemática de resumen a `web/js/core/finance-math.js` para poder probarla de forma ejecutable.
- Se verifica separación `cuota / material / otro`, total generado, cobrado acotado por cargo, pendiente, vencido y deudores únicos.
- Se mantiene 031 como puerta obligatoria de Supabase real, ya que no estaba aplicada según confirmación del usuario.

### 3. Likes en Comunidad

- Un like máximo por usuario/publicación.
- Dar/quitar like.
- Contador consistente por trigger.
- La identidad de los likes no se expone: el cliente solo conoce el estado propio y el contador.
- Aislamiento por club y escritura por gateway.

### 4. Perfil deportivo/social

- Nueva tabla `perfiles_deportivos` separada del perfil administrativo.
- Datos voluntarios deportivos: apodo, presentación, experiencia, guardia, técnica favorita, especialidad, categoría, competiciones/logros y objetivos.
- Disciplina/grado/grupo se derivan de las matrículas oficiales existentes.
- Tutor vinculado puede editar el perfil del menor.
- Privacidad voluntaria (`visible`) separada de moderación (`moderacion_oculta`).
- RPC de lectura segura, sin email, teléfono, dirección, fecha de nacimiento completa, documentos ni finanzas.
- Bucket privado `sports-profile-media`.
- Navegación desde Comunidad y directorio sencillo de miembros.

### 5. Eventos / competiciones

- Eventos con fecha, lugar, disciplina, estado, plazo y requisitos.
- Participantes internos enlazados a socio.
- Participantes externos sin cuenta/app y sin datos de contacto innecesarios.
- Solicitud, confirmación, rechazo y baja.
- Equipo autorizado puede completar inscritos tras el cierre de inscripción, salvo evento finalizado/cancelado.
- Combates manuales con A/B, categoría, disciplina, tatami/ring, orden, hora, estado, resultado y ganador.
- No se implementan brackets automáticos en el MVP.

### 6. Seguridad / backend

- Toda escritura nueva pasa por `app_mutate_v160`.
- 032 encadena el gateway/contrato previo; 033 encadena 032.
- Frontend RC13 exige las 12 capacidades nuevas del contrato antes de operar; un backend RC12 incompleto no se acepta silenciosamente.
- Participantes y combates no tienen SELECT directo para el cliente: usan RPCs seguras.
- Perfiles deportivos tampoco tienen SELECT directo para el cliente.
- Lecturas y mutaciones nuevas aplican aislamiento por club.
- Funciones `SECURITY DEFINER` nuevas fijan `search_path=public,auth`.

## Migraciones nuevas

### 032 · Social

- `supabase/migrations/032_social_profiles_likes.sql`
- `supabase/verification/preflight_032_social.sql`
- `supabase/verification/verify_032_social.sql`
- `supabase/rollbacks/032_social_profiles_likes.sql`

### 033 · Eventos

- `supabase/migrations/033_events_competitions.sql`
- `supabase/verification/preflight_033_events.sql`
- `supabase/verification/verify_033_events.sql`
- `supabase/rollbacks/033_events_competitions.sql`

La migración 031 incluida en RC12 **no se ha alterado**.

## Pruebas automáticas realizadas

### Suite completa

Comando:

```bash
npm test
```

Resultado: **PASS**.

- 24 suites/bloques con marcador `PASS`.
- 487 comprobaciones `OK` en la ejecución final registrada.
- Contrato RC13: `86/86` operaciones de `app_mutate_v160` implementadas según la prueba de contrato.
- Regresiones históricas RC4–RC12 incluidas.
- Nuevas pruebas RC13 de finanzas, capability gate, perfiles/likes, eventos, responsive y cadena SQL.

### Sintaxis JavaScript

Se ejecutó `node --check` sobre 51 archivos `.js/.mjs` de `web/js` y `scripts`.

Resultado: **51/51 sin error de sintaxis**.

### Build

Comando:

```bash
npm run build
```

Resultado final:

```text
OK build 48 archivos · web = dist = Android
```

### Paridad exacta

Se ejecutó comparación recursiva:

- `web` vs `dist`: **idénticos**.
- `web` vs `android/app/src/main/assets/www`: **idénticos**.

### Integridad del diff

Comando:

```bash
git diff --check
```

Resultado: **sin errores de whitespace/diff**.

### Conservación de Finanzas 031

No existen cambios Git sobre:

`supabase/migrations/031_finance_receipts_breakdown.sql`

Las nuevas migraciones empiezan en 032.

## Correcciones defensivas aplicadas durante la revisión

- Separación entre privacidad elegida por alumno/tutor y bloqueo de moderación.
- Un moderador no puede publicar un perfil privado del titular.
- Subir solo una foto deportiva no publica el perfil accidentalmente.
- FK del autor de Comunidad evita un `SET NULL` compuesto que podría intentar anular `club_id`.
- FK de disciplina/ganador en Eventos evita el mismo riesgo de `SET NULL` compuesto.
- No se puede pasar a rechazo/baja un participante con combate activo sin cancelar/eliminar primero el combate.
- El ganador debe ser uno de los dos participantes.
- Solo confirmados pueden formar un combate.
- Se eliminó un flujo UI basado en temporizadores para alta de alumnos en evento; ahora el alta es atómica en un único formulario.
- El cliente RC13 falla de forma controlada si el backend no publica 032/033 completas.

## Puertas que todavía NO pueden declararse certificadas localmente

La ausencia de fallos automáticos no equivale al freeze final. Quedan obligatoriamente:

1. Backup y certificación del Supabase real.
2. Audit 023–030.
3. Aplicación/verificación/transaccional de 031.
4. Preflight + aplicación + verificación + RLS manual de 032.
5. Preflight + aplicación + verificación + negocio/RLS manual de 033.
6. Prueba real por roles.
7. Validación visual en PC y web móvil con backend real.
8. Prueba física Android, push, selector multimedia, foreground/background y navegación del sistema.
9. Solo después: commit/tag de freeze, push y Netlify desde el SHA exacto.

## Estado final de esta entrega

**Candidata RC13 build 20017 implementada y certificada localmente a nivel estático, unitario, contractual, regresivo y de build.**

No se afirma todavía que Supabase real, RLS real, Netlify o una APK física estén certificados. Esa certificación requiere ejecutar el runbook y la matriz manual incluidos con la entrega.
