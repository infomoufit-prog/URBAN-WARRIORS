# Urban Warriors · Despliegue

> Esta lista sustituye a la versión anterior, que solo documentaba las migraciones
> 001–005. Ese vacío formaba parte de la causa raíz del fallo de persistencia de
> la 1.6.0: nadie que siguiera el checklist llegaba a aplicar 015, 016 ni 017.

## Orden obligatorio

El orden importa. La migración 015 instala la única puerta de escritura de la
aplicación (`app_mutate_v160`) y ejecuta un smoke test real contra ella. Ese
smoke test necesita una cuenta con rol `direccion` activa; por eso el paso 5 va
antes que el paso 6.

### 1. Configuración del cliente

Editar `web/config.js`:

- `demoMode: false`
- `supabase.url` y `supabase.anonKey` del proyecto (clave `sb_publishable_*`)
- `release.webUrl` con la URL de Netlify
- `release.backendVersion: '1.6.0'` y `release.schemaEpoch: 160` deben coincidir
  con lo que devuelve `app_runtime_meta`. Si no coinciden, la app bloquea todo
  guardado a propósito.

### 2. Migraciones base

En Supabase → SQL Editor, **un archivo cada vez y en este orden**:

```
001_phase1_complete.sql
002_access_payments_posts_notifications.sql
003_extend_fee_status.sql
004_payment_reminders_workflow.sql
005_security_hardening.sql
006_production_runtime_fixes.sql
007_operational_v130.sql
008_audit_operational_v131.sql
009_final_operational_v140.sql
010_family_multisport_firebase_final.sql
012_operational_integrity_v152.sql     <- no existe 011; 012 la absorbe
013_autotest_signature_fix_v152.sql
014_autotest_notification_fix_v152.sql
```

Cada archivo debe terminar en `Success`. Si uno falla, **para**: el SQL Editor
ejecuta cada archivo en una transacción y lo revierte entero, así que continuar
deja el esquema a medias.

### 3. Datos iniciales del club

```
supabase/setup/bootstrap_urban_warriors_club.sql
```

No ejecutar `supabase/seed.sql` ni nada de `docs/reference/` en producción.

### 4. Storage

Crear el bucket **privado** `justificantes-pago` y el bucket **público**
`club-public-media`.

### 5. Primera cuenta de dirección  <- paso crítico

1. Supabase → Authentication → Users → crear la cuenta de dirección (correo y
   contraseña reales de la persona responsable del club).
2. Aplicar `017_persistence_recovery_v161.sql`, que instala el bootstrap.
3. Promover esa cuenta a Dirección:

```sql
select public.app_bootstrap_direccion('correo@delclub.com');
```

Debe devolver `{"ok": true, "rol": "direccion", ...}`.

> Sin este paso, la 015 instala la puerta pero **omite** el smoke test y lo avisa
> por `NOTICE`. La escritura queda sin certificar hasta que se repita el paso 6.

### 6. Gobernanza de escritura y recibos

```
015_mutation_governance_v160.sql
016_recibos_cuota.sql
017_persistence_recovery_v161.sql       <- reejecutar para resellar permisos
```

La 015 debe terminar en `Success` **y** sin el aviso `V160_SMOKE_OMITIDO`. Si
aparece ese aviso, la cuenta de dirección del paso 5 no está activa.

### 7. Verificación antes de publicar

```sql
select * from public.app_diagnostico_persistencia_v161();
```

Los nueve controles deben salir en `OK`. Un `AVISO` en «RPC heredadas cerradas»
o en «DML directo cerrado» significa que se reejecutó 007, 008 o 012 después de
015 y se reabrió la ruta de escritura antigua: basta con volver a lanzar la 017.

Desde el navegador, con sesión iniciada, en la consola:

```js
await store.runFinalDiagnostic()
```

### 8. Netlify

- `netlify.toml` fija `NODE_VERSION = "22"`. No quitarlo: el build usa
  `import.meta.dirname`, que exige Node >= 20.11. Con un runtime más antiguo el
  build falla y Netlify **mantiene publicado el deploy anterior**, de modo que
  los cambios parecen no aplicarse.
- El comando `npm run build` ejecuta el preflight de gobernanza. Si falla, no se
  publica nada: es intencionado.

### 9. Edge Functions y avisos

Desplegar `payment-reminders` y `notification-dispatch`, añadir `UW_CRON_SECRET`
y programar el Cron con los ejemplos de `supabase/cron_*.sql.example`.

### 10. Android

`npm run android:prepare` y después `android:debug` / `android:release`. El build
verifica SHA-256 de los 23 assets entre `web/`, `dist/` y los assets de Android:
si difieren, aborta.

---

## Verificación local antes de desplegar

```bash
npm test                                   # suites estáticas + SQL real
npm install --no-save @electric-sql/pglite # solo la primera vez
npm run test:sql                           # aplica 001->017 sobre PostgreSQL real
```

`test:sql` levanta un PostgreSQL en WASM, aplica todas las migraciones sobre una
base vacía y ejecuta una escritura real por la puerta. Se omite sin romper el
build si PGlite no está instalado, para no ralentizar Netlify.

## Recuperación de un entorno ya roto

Si la app entra pero no guarda nada:

1. `select * from public.app_diagnostico_persistencia_v161();`
   (si la función no existe, aplicar 017 primero).
2. Si falta la puerta: paso 5 y después paso 6.
3. Si sale `AVISO` en permisos: reejecutar 017.
4. Si las funciones existen pero el navegador recibe 404: `notify pgrst, 'reload schema';`
