# Informe técnico · Urban Warriors 1.6.0 build 13

**Objeto:** fallo de persistencia en producción (Netlify + Supabase).
**Método:** auditoría desde cero del ZIP completo, sin dar por válida la auditoría
previa, y **ejecución real** de las migraciones sobre un PostgreSQL levantado en
el entorno de análisis (PGlite/WASM, PostgreSQL 16) con el `data-store.js` real
del proyecto conectado contra él mediante un shim de PostgREST.

---

## 1. Causa raíz real

**La migración `015_mutation_governance_v160.sql` abortaba sobre cualquier base
que todavía no tuviera una cuenta con rol `direccion` activa, y al abortar
revertía la migración completa. La puerta de escritura de la aplicación nunca
llegaba a existir.**

Línea 704 del archivo original:

```sql
if v_club is null or v_direction is null then
  raise exception 'V160_SMOKE_NO_ACTIVE_DIRECTION';
end if;
```

El SQL Editor de Supabase ejecuta cada archivo en **una única transacción**. La
excepción del smoke test revierte todo lo anterior del mismo archivo: la tabla
`app_runtime_meta`, la tabla `app_mutation_requests`, las funciones
`app_mutate_v160`, `app_runtime_contract_v160` y `app_write_channel_probe_v160`,
y también el `notify pgrst, 'reload schema'` de la última línea.

Es una **dependencia circular de diseño**: 015 exige una cuenta de dirección, y
la única vía documentada para crearla pasaba por la propia aplicación, que no
puede escribir sin 015.

### Evidencia (ejecución real, base limpia, orden documentado)

```
OK    001_phase1_complete.sql
OK    002 … 010, 012, 013, 014
FALLO 015_mutation_governance_v160.sql :: V160_SMOKE_NO_ACTIVE_DIRECTION
OK    016_recibos_cuota.sql

¿existe app_mutate_v160?            false
¿existe app_runtime_contract_v160?  false
¿existe recibos_cuota (016)?        true
```

Obsérvese que **016 sí se instala**. La base de datos queda con aspecto de
completa: existen todas las tablas, todas las políticas RLS y hasta la tabla de
recibos de la última versión. Lo único que falta es exactamente aquello sin lo
que no se puede escribir nada.

### Por qué el síntoma es «entro como administrador pero no se guarda»

`data-store.js` persistía la sesión **antes** de validar el contrato de backend:

```js
localStorage.setItem(SESSION_KEY, JSON.stringify(this.session));
await this.ensureBackendContract(true);   // aquí lanza
await this.loadRemote();
```

Ejecutado contra la base sin la puerta, el resultado real fue:

```
store.login() lanzó error:          SÍ → "Backend de guardado no preparado:
                                    Could not find the function
                                    public.app_runtime_contract_v160(p_club_id)
                                    in the schema cache"
¿store.getSession() está poblada?   SÍ (rol=direccion)
¿sesión persistida en localStorage? SÍ
filas en public.disciplinas:        0
```

El login falla, `app.js` muestra un toast de 3,6 segundos… y `store.session` ya
está poblada. Como `currentUser()` es truthy e `isAdmin()` devuelve `true`, el
siguiente `render()` pinta el panel de administración completo. El usuario cree
que ha entrado como administrador y que la aplicación «simplemente no guarda».

---

## 2. Corrección de la auditoría anterior

La auditoría previa identificó bien la causa raíz (hipótesis C1), pero contenía
**un razonamiento erróneo** que aquí queda rectificado:

> «Si la usuaria puede iniciar sesión y llegar al panel, entonces
> `app_runtime_contract_v160` existe y la migración 015 está aplicada.»

Es **falso**. Como demuestra la ejecución anterior, se puede llegar al panel de
administración con el contrato fallando, porque la sesión se guardaba antes de
validarlo. La inferencia era razonable leyendo el código en diagonal y resultó
incorrecta al ejecutarlo.

Otras dos afirmaciones del informe previo se han verificado y **no eran
defectos**:

- El formulario de alumno sí marca `disciplina_id` y `grupo_id` como `required`,
  de modo que no hay desajuste con la validación del backend. Lo que en la
  auditoría anterior parecía un fallo era un artefacto de mi propia prueba.
- El service worker no es causa del problema: es *network-first*, con
  `skipWaiting()` y `clients.claim()`, y no intercepta orígenes externos.

---

## 3. Segundo defecto real, independiente y también demostrado

`app.js` autoriza en la interfaz a cuatro roles:

```js
function isAdmin() { return ['direccion','secretaria','economia','comunicacion'].includes(currentUser()?.rol); }
```

Las RPC de catálogo (`app_guardar_disciplina`, `_grado`, `_grupo`, `_socio`)
aceptan solo dos:

```sql
if not public.tiene_rol_club(p_club_id,'direccion','secretaria') then
  raise exception 'No tienes permiso para gestionar disciplinas';
```

Ejecutado con la puerta ya instalada y una cuenta con rol `economia`:

```
FALLO disciplina.guardar (rol economia) :: No tienes permiso para gestionar disciplinas
```

**Gravedad:** alta si el club opera con cuentas de Economía o Comunicación.
Producía el mismo síntoma («veo el botón, pulso, no se guarda») por una causa
completamente distinta, lo que habría enmascarado el diagnóstico incluso después
de arreglar la migración.

---

## 4. Defectos estructurales adicionales encontrados

| # | Ubicación | Defecto | Gravedad |
|---|---|---|---|
| E1 | `data-store.js:585` | `safeSelect` silenciaba los errores de las 32 lecturas de `loadRemote`. Una tabla ausente o una policy rota devolvía `[]`: pantalla vacía, indistinguible de «no se ha guardado» | Alta |
| E2 | `data-store.js:1208` | `runFinalDiagnostic()` nunca se invocaba desde `app.js`. Código muerto | Alta |
| E3 | `data-store.js:303` | `writeBlockedReason` se calculaba y jamás se mostraba | Alta |
| E4 | `app.js:26` | Único canal de error: toast de 3,6 s. Los mensajes largos de PostgREST se pierden antes de poder leerlos | Media |
| E5 | `scripts/test-browser-channel-v160.mjs` | Mockea el servidor entero: no puede fallar por ninguna causa de backend. Aun así el manifiesto lo presentaba como certificación del canal | Alta (gobernanza) |
| E6 | Toda la suite 1.6.0 | Ninguna prueba ejecutaba SQL. Por eso 28/28 controles daban verde con la puerta de escritura inexistente | Alta (gobernanza) |
| E7 | `DEPLOYMENT_CHECKLIST.md` | Documentaba solo migraciones 001–005 | Alta |
| E8 | `007`, `008`, `012` | Terminan con `grant execute … to authenticated` sobre las RPC heredadas. Reejecutarlas tras 015 reabre la ruta no gobernada sin aviso | Media |
| E9 | `netlify.toml` | Sin `NODE_VERSION`. El build usa `import.meta.dirname` (Node ≥ 20.11); con un runtime menor el build falla y Netlify mantiene publicado el deploy anterior | Media |
| E10 | `001_phase1_complete.sql` | 56 `create policy` sin `drop policy if exists`: no es reejecutable | Media |
| E11 | migraciones | No existe `011`; solo consta en un comentario dentro de 012 | Baja |
| E12 | `016:244` | `app_diagnostico_recibos_v160` con GRANT solo a `service_role`/`postgres`: inservible desde la app | Baja |
| E13 | `data-store.js:748` | `normalizePayload()` no se llama desde ningún sitio. Código muerto (~40 líneas) | Baja |
| E14 | `web/config.js` | URL y clave codificadas en el repositorio. La clave publishable es pública por diseño, pero impide separar preproducción y producción | Baja |

---

## 5. Cambios realizados

Principio aplicado: **mínimo, aditivo y reversible**. No se ha alterado la
arquitectura, ni el contrato 1.6.0, ni la firma de ninguna RPC, ni se ha
eliminado ninguna funcionalidad.

### 5.1 SQL

**`supabase/migrations/015_mutation_governance_v160.sql`** — un solo cambio:

```sql
if v_club is null or v_direction is null then
  raise notice 'V160_SMOKE_OMITIDO: …';
  return;
end if;
```

*Por qué es necesario:* la ausencia de una cuenta de dirección es la condición
normal de un club recién creado, no un fallo de gobernanza. Antes abortaba la
migración entera.
*Por qué no hay solución mejor:* cualquier alternativa (una 018 que replique el
cuerpo de 015) duplicaría 760 líneas de SQL. Editar la migración es aquí legítimo
porque en el entorno afectado **nunca llegó a aplicarse**, y en los entornos
donde sí se aplicó el cambio es un no-op: el comportamiento es idéntico en cuanto
existe una cuenta de dirección. La verificación estructural del bloque 6 sigue
abortando si la gobernanza queda incompleta, que es el fallo que sí debe romper
un despliegue.

**`supabase/migrations/017_persistence_recovery_v161.sql`** — nueva, idempotente:

1. `app_bootstrap_direccion(email, club_slug)` — rompe la dependencia circular.
   `SECURITY DEFINER`, con GRANT solo a `postgres`/`service_role`: nunca
   invocable desde el navegador.
2. Resellado idempotente de permisos: recorre `pg_proc` y revoca de
   `anon`/`authenticated` todas las RPC heredadas de mutación. Corrige E8 y
   permite recuperarse de una regresión sin reinstalar nada.
3. `app_diagnostico_persistencia_v161()` — nueve controles del estado real de la
   cadena de persistencia. Informa, no aborta.
4. `notify pgrst, 'reload schema'`.

Protegida con `to_regclass` para poder ejecutarse en cualquier orden y estado,
incluso antes de 015 (verificado).

### 5.2 Frontend

**`web/js/data-store.js`**

- `login()`: la sesión ya no se persiste hasta que `ensureBackendContract()` y
  `loadRemote()` han terminado. Si fallan, se limpia sesión, contrato,
  `localStorage` y la sesión de Supabase. *Corrige el mecanismo exacto del
  síntoma reportado.*
- `safeSelect()`: registra cada fallo en `store.loadErrors` además del
  `console.warn`. Aditivo, sin cambio de comportamiento en el camino feliz.
- `loadErrors: []` declarado en el store y reiniciado al inicio de `loadRemote()`.

**`web/js/app.js`**

- `systemBanner()` en `renderShell()`: aviso persistente y literal cuando
  `writeBlockedReason` no es nulo o hay `loadErrors`. Consume el código que ya
  existía sin usarse (E2, E3).
- Acción `run-diagnostic`: conecta el botón del banner a
  `store.runFinalDiagnostic()`, que llevaba desde 1.6.0 sin invocarse.
- `canManageCatalog()` = `direccion` | `secretaria`, aplicado a los botones de
  disciplina, grado y grupo en las tres pantallas que los muestran. No se toca
  `isAdmin()`, de modo que Economía y Comunicación conservan todo lo demás.

### 5.3 Build, pruebas y documentación

- `netlify.toml`: `NODE_VERSION = "22"` (E9).
- `scripts/test-sql-migrations-v161.mjs`: nueva suite que levanta un PostgreSQL
  real, aplica 001→017 sobre base vacía, verifica diez controles de gobernanza y
  ejecuta una escritura real por la puerta. Se **omite sin fallar** si PGlite no
  está instalado, para no añadir dependencias ni tiempo al build de Netlify.
  Corrige E6: esta suite sí habría detectado el fallo.
- `package.json`: `npm run test:sql`, y la suite añadida a `npm test`. El
  comando `build` queda intacto.
- `DEPLOYMENT_CHECKLIST.md`: reescrito con el orden real 001→017, el paso de
  creación de la cuenta de dirección **antes** de 015, verificación posterior y
  procedimiento de recuperación de un entorno ya roto.
- Build 12 → 13 en los seis puntos de versión (`config.js`, `service-worker.js`,
  `index.html`, `build.gradle` y las dos suites que lo asertan), necesario para
  que el service worker sirva el runtime corregido.

---

## 6. Pruebas realizadas y resultado

### 6.1 Suite completa del proyecto

```
OK: 28 controles de gobernanza 1.6.0.
OK: compatibilidad SQL 015 con 13 migraciones previas, 35 firmas legacy y 32 tablas.
OK: canal navegador → contrato → gateway.
OK: 21 archivos esenciales, migración 007, CRUD operativo, Storage, progreso.
OK: agrupación familiar, 5 días configurables, idempotencia, justificante, pausa.
OK: 11 controles de recibos Urban Warriors.
OK: preflight de producción 1.6.0 (7 archivos críticos).
OK: migraciones 001→017 aplicadas sobre PostgreSQL real y 10 controles verificados.
```

### 6.2 Build gobernado

```
OK build13
Build web: dist
Assets Android: android/app/src/main/assets/www
OK: 23 archivos idénticos web ↔ dist ↔ Android.
```

### 6.3 Extremo a extremo sobre PostgreSQL real, con el cliente corregido

```
1. Migraciones 001→017, base limpia ........... 16/16 OK
2. app_bootstrap_direccion .................... {"ok":true,"rol":"direccion"}
3. Reejecución de 015 ......................... OK, smoke test real superado
4. login() real del cliente
     sesión válida: true | rol: direccion | contrato: 1.6.0
     writeBlockedReason: null | loadErrors: 0
5. Altas reales desde el cliente
     OK crear disciplina
     OK crear grupo + horario
     OK crear grado
     OK crear tarifa
     OK crear alumno con matrícula
     OK actualizar disciplina
6. Persistencia verificada en la base
     disciplinas=1  grados=1  grupos=1  horarios_grupo=1
     tarifas=1  socios=1  socio_disciplinas=1  app_mutation_requests=7
7. Recarga completa (lectura)
     disciplinas=1 grupos=1 horarios=1 tarifas=1 socios=1 · loadErrors: ninguno
8. Diagnóstico 017 ............................ 9/9 OK
```

### 6.4 Regresión del síntoma original

Contra una base **sin** la puerta instalada, con el cliente corregido:

```
store.login() lanzó error:          SÍ → "Backend de guardado no preparado: …"
¿store.getSession() está poblada?   NO      (antes: SÍ, rol=direccion)
¿sesión persistida en localStorage? NO      (antes: SÍ)
filas en public.disciplinas:        0
store.writeBlockedReason:           mensaje literal disponible para el banner
```

Ya no existe la sesión de administrador fantasma. El usuario se queda en la
pantalla de acceso con la causa exacta visible de forma persistente.

### 6.5 Idempotencia y robustez de orden

- Mismo `request_id` dos veces → misma `id` devuelta, **una sola fila** en la
  base. Idempotencia confirmada contra PostgreSQL real.
- `017` ejecutada sobre una base sin `015`: instala sin abortar y deja
  `app_bootstrap_direccion` disponible. Verificado.

---

## 7. Auditoría de seguridad

- La clave `sb_publishable_*` se usa exclusivamente como `apikey`; `Authorization`
  solo transporta el `access_token` real del usuario. **Correcto.**
- Ruta de escritura única `SECURITY DEFINER` con verificación de membresía e
  idempotencia por `request_id`. **Correcto.**
- DML directo revocado a `anon`/`authenticated` en las 31 tablas funcionales.
  **Correcto**, y ahora resellable con 017.
- `app_bootstrap_direccion` es la única función nueva con capacidad de conceder
  roles: revocada a `public`, `anon` y `authenticated`. Solo ejecutable desde el
  SQL Editor o con `service_role`.
- **Pendiente:** RLS de `app_mutation_requests` está activo sin políticas y con
  todo revocado, lo cual es correcto, pero depende de que el propietario de la
  función sea `postgres`. Si alguna vez se aplican las migraciones con otro rol,
  conviene revisarlo.

## 8. Auditoría de rendimiento

- `loadRemote()` lanza **32 SELECT en paralelo** en cada guardado, porque todas
  las funciones `save*` llaman a `loadRemote()` al terminar. Con un club de
  cientos de socios esto es una recarga completa por cada alta. Funciona, pero es
  el principal candidato a optimización futura (recarga selectiva por colección).
- `historial_avisos_cuota` ya está limitado a 250 filas; el resto no tiene
  paginación.

## 9. Auditoría de consistencia

- Idempotencia verificada contra PostgreSQL real.
- Las escrituras compuestas (grupo + horarios, alumno + matrícula) ocurren dentro
  de una única función `SECURITY DEFINER`, es decir, en una sola transacción. No
  hay estados intermedios visibles.
- Compensación de Storage: si el registro posterior a una subida falla, la app
  borra el binario. Correcto, aunque el borrado no es transaccional (aceptable).

## 10. Deuda técnica pendiente (no corregida, por decisión)

| # | Asunto | Motivo de no tocarlo ahora |
|---|---|---|
| D1 | `normalizePayload()` sin uso (~40 líneas) | Eliminarlo no aporta y toca código estable |
| D2 | `001` no reejecutable (policies sin `drop if exists`) | Reescribirla es un riesgo mayor que el beneficio; documentado en el checklist |
| D3 | `test-browser-channel-v160.mjs` mockea el servidor | Se ha compensado añadiendo la suite SQL real en vez de reescribirla |
| D4 | Las suites hardcodean el número de build | Obliga a editar los tests en cada release. Debería leerse de `config.js` |
| D5 | `config.js` con credenciales en el repositorio | Generarlo en build desde variables de Netlify permitiría separar pre/pro |
| D6 | `loadRemote()` recarga las 32 tablas tras cada guardado | Optimización, no corrección |
| D7 | No existe `011` | Solo confunde; renumerar rompería historiales |

---

## 11. Conclusión

El fallo de persistencia **no estaba en el frontend ni en la arquitectura**. La
puerta de escritura versionada, la idempotencia y el cierre de rutas antiguas
están bien diseñados y, una vez instalados, funcionan: se ha demostrado creando
disciplinas, grados, grupos, horarios, tarifas y alumnos contra un PostgreSQL
real con el `data-store.js` del proyecto sin modificar.

El sistema no persistía porque **la migración que instala esa puerta se revertía
a sí misma** en cualquier club que aún no tuviera una cuenta de dirección, y
porque el cliente daba por buena una sesión que el backend nunca había validado,
mostrando un panel de administración incapaz de escribir.

Ambas cosas están corregidas, con un cambio de seis líneas en 015, una migración
aditiva, cuatro cambios quirúrgicos en el cliente y una suite de pruebas que
ahora sí ejecuta SQL de verdad y habría detectado el fallo original.

### Límite honesto de esta certificación

Toda la validación se ha hecho contra PostgreSQL 16 en WASM con un stub del
esquema `auth` de Supabase y un shim de PostgREST. Es incomparablemente más
sólido que el análisis estático anterior, pero **no sustituye a la ejecución en
el proyecto real**. La certificación de producción se cierra cuando:

1. `select * from public.app_diagnostico_persistencia_v161();` devuelva 9 × `OK`
   en tu proyecto Supabase, y
2. el deploy de Netlify figure como `Published` con build 13.
