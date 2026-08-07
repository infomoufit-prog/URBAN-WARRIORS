# Build 14 · Estabilización previa a certificación

Partida: build 13 (corrección de persistencia). Alcance: **solo** las dos
correcciones solicitadas. No hay auditoría nueva, ni refactorización, ni cambios
de arquitectura, contrato 1.6.0, persistencia, login o gobernanza.

---

## Corrección 1 · Punto único de decisión del catálogo

**Problema.** En el build 13 `canManageCatalog()` cubría la barra de herramientas
y el botón de editar grupo, pero seguían visibles para `economia` y
`comunicacion`: Editar disciplina, Añadir grado, Editar grado y
Activar/Desactivar disciplina. El backend las rechazaba después.

**Solución.** Un único criterio y dos mecanismos que lo aplican:

```js
function canManageCatalog() { return ['direccion', 'secretaria'].includes(currentUser()?.rol); }
const CATALOG_ACTIONS = ['open-discipline-form', 'open-grade-form', 'open-group-form'];
const CATALOG_DATASET_KEYS = ['editDiscipline', 'toggleDiscipline', 'addGrade', 'editGrade', 'editGroup'];
function catalogControl(html) { return canManageCatalog() ? html : ''; }
function isCatalogTarget(target) { … }
```

1. **Render:** los 11 controles de catálogo de las tres pantallas pasan por
   `catalogControl()`. Ninguna pantalla vuelve a comprobar roles por su cuenta.
2. **Ejecución:** un guardián en el despachador de clics bloquea cualquier acción
   de catálogo aunque un control llegara a renderizarse por error.

La lista de roles aparece **una sola vez** en todo `app.js`.

**Degradación de la vista, sin pérdida de información.** Los grados, que eran
botones editables, se renderizan como etiquetas `<span>` cuando no hay permiso;
la escala de grados se sigue viendo. La pantalla de disciplinas muestra el aviso
«Solo Dirección y Secretaría pueden modificar el catálogo».

**Controles antirregresión** añadidos a `test-governance-v160.mjs` (28 → 31):

```
OK controles de catálogo envueltos en catalogControl — 11 controles; 0 sin envolver
OK guardián único de catálogo en el despachador
OK rol de catálogo declarado una sola vez
```

## Corrección 2 · Separación de certificación rápida y completa

**Problema.** La suite SQL se omitía sin PGlite y `npm test` salía todo en verde,
de modo que un `SKIP` podía leerse como certificación.

**Solución.** Dos modos en el mismo script, sin duplicar código:

| Comando | Comportamiento sin PGlite |
|---|---|
| `npm run build` (Netlify) | No incluye la suite SQL. Sin cambios |
| `npm test` | Omite, pero imprime un bloque **ATENCIÓN · CERTIFICACIÓN SQL OMITIDA (NO ES UN APROBADO)**. Salida 0 |
| `npm run test:sql:strict` | **Falla con salida 1** y bloque «CERTIFICACIÓN SQL FALLIDA» |
| `npm run certify` | `npm test` + modo estricto. Es el comando de certificación |

Cuando sí se ejecuta, el mensaje final es inequívoco:
`OK: CERTIFICACIÓN SQL REAL SUPERADA — migraciones 001→017 aplicadas sobre PostgreSQL`.

---

## Archivos modificados en el build 14 (6)

| Archivo | Cambio |
|---|---|
| `web/js/app.js` | Punto único de decisión del catálogo: `CATALOG_ACTIONS`, `CATALOG_DATASET_KEYS`, `catalogControl()`, `isCatalogTarget()`, guardián en el despachador y 7 bloques de render reencaminados |
| `scripts/test-sql-migrations-v161.mjs` | Modo estricto `--require-db` / `UW_REQUIRE_DB=1`; mensajes inequívocos de omisión, fallo y aprobado |
| `package.json` | Scripts `test:sql:strict` y `certify`. `build` y `test` sin tocar en su composición |
| `scripts/test-governance-v160.mjs` | 3 controles antirregresión del catálogo + bump de build |
| `web/config.js`, `web/index.html`, `web/service-worker.js`, `android/app/build.gradle`, `scripts/test-receipts-v160.mjs`, `scripts/test-production-v160.mjs` | Bump 13 → 14 (necesario para que el service worker sirva el runtime nuevo) |
| `android/app/src/main/assets/www/**` | Regenerado por `scripts/build.mjs`, verificado por SHA-256 |

**Sin tocar:** ninguna migración, ninguna RPC, ninguna política RLS,
`data-store.js`, `netlify.toml`, `DEPLOYMENT_CHECKLIST.md`, `web/css/app.css`,
`push.js`, `demo-data.js`, `build.mjs` ni el resto de suites.

---

## Pruebas ejecutadas

### Suites del proyecto

```
OK: 31 controles de gobernanza 1.6.0.
OK: compatibilidad SQL 015 con 13 migraciones previas, 35 firmas legacy y 32 tablas.
OK: canal navegador → contrato → gateway.
OK: 21 archivos esenciales, migración 007, CRUD operativo, Storage, progreso.
OK: agrupación familiar, 5 días configurables, idempotencia, justificante, pausa.
OK: 11 controles de recibos Urban Warriors.
OK: preflight de producción 1.6.0 (7 archivos críticos).
OK: CERTIFICACIÓN SQL REAL SUPERADA — migraciones 001→017 y 10 controles.
```

### Modos de certificación

```
npm test            sin PGlite  → verde + aviso de omisión, salida 0
test:sql:strict     sin PGlite  → "CERTIFICACIÓN SQL FALLIDA", salida 1  ✔
npm run certify     con PGlite  → CERTIFICACIÓN SQL REAL SUPERADA
```

### No regresión, contra PostgreSQL real

```
Migraciones 001→017, base limpia .............. 16/16 OK
app_bootstrap_direccion ....................... {"ok":true,"rol":"direccion"}
015 reejecutada, smoke test real .............. superado
login() del cliente ........................... sesión válida, contrato 1.6.0,
                                                writeBlockedReason null, loadErrors 0
Altas: disciplina, grupo+horario, grado,
       tarifa, alumno con matrícula, update ... 6/6 OK
Persistencia en base .......................... disciplinas 1, grados 1, grupos 1,
                                                horarios 1, tarifas 1, socios 1,
                                                socio_disciplinas 1
Recarga completa (lectura) .................... sin loadErrors
Diagnóstico 017 ............................... 9/9 OK
```

### Cuotas y recibos (cadena completa)

```
cuotas.generar ................ {"creadas":1}
cuota creada .................. importe 45.00, estado pendiente
pago.registrar_admin .......... OK
estado de la cuota ............ pagada
recibo emitido por trigger .... UW-2026-000001 · periodo 2026-08-01 · 45.00 · MT
```

### PWA y Android

```
OK build14
CACHE = 'urban-warriors-v1.6.0-build14'
config.js build: 14 · index.html 7 cache-bust ?v=1.6.0-b14 · versionCode 14
OK: 23 archivos idénticos web ↔ dist ↔ Android
diff web/js/app.js ↔ assets/www/js/app.js → sin diferencias
```

**Sin regresiones detectadas.**

---

## Detectado y NO corregido (para una versión futura)

Siguiendo la instrucción de documentar en lugar de corregir:

**P1 · Los roles de tarifas, material y comunicaciones tampoco coinciden entre
interfaz y backend.** La Corrección 1 se ha limitado al catálogo, tal y como se
pidió. Las firmas reales son:

| RPC | Roles que acepta el backend |
|---|---|
| `app_guardar_tarifa` | `direccion`, `economia` — **no** `secretaria` |
| `app_guardar_material` | `direccion`, `economia`, `secretaria` |
| `app_guardar_variante_material` | `direccion`, `secretaria`, `economia` |
| `app_guardar_comunicacion` | `direccion`, `comunicacion` |

En la interfaz, `canManageFinance()` incluye `secretaria`, que el backend
rechaza para tarifas; y las publicaciones se ofrecen a los cuatro roles de
`isAdmin()` cuando solo dos las pueden guardar. **No se ha tocado nada de esto**
porque habría implicado retirar controles a roles que hoy sí los usan
legítimamente y quedaba fuera del alcance del build 14.

**P2 · `app_guardar_grado` acepta además el rol `monitor` en el backend.** La
interfaz ahora es más restrictiva que el servidor para grados (solo Dirección y
Secretaría), que es exactamente lo solicitado. Se documenta la discrepancia por
si en el futuro se quiere permitir que los monitores registren grados.

**P3 · La verificación de la Corrección 1 es estática** (11 controles envueltos,
guardián presente, rol declarado una sola vez) más el guardián en tiempo de
ejecución. No se ha montado un DOM para renderizar la aplicación con un rol
`economia` y comprobar visualmente el resultado; no hay infraestructura de
pruebas de interfaz en el proyecto y crearla habría sido una funcionalidad nueva.

**P4 · Deuda ya conocida del build 13**, sin cambios: `normalizePayload()` sin
uso, `001` no reejecutable, `test-browser-channel-v160.mjs` mockea el servidor,
las suites codifican el número de build a mano y `loadRemote()` recarga las 32
tablas tras cada guardado.
