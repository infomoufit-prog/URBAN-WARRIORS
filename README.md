# Urban Warriors 2.0.0-rc.1

Reconstrucción modular del frontend de Urban Warriors sobre el backend Supabase existente.

## Objetivo de esta RC

Eliminar el frontend monolítico de 1.6.x y conservar como API estable:

- Supabase Auth
- PostgreSQL + RLS
- Storage
- contrato backend `1.6.0`
- `schema epoch 160`
- puerta única `app_mutate_v160`
- diagnóstico `app_diagnostico_persistencia_v161`

La aplicación web nueva no reutiliza `UW_STORE`, no tiene modo demo paralelo y no realiza DML directo.

## Módulos incluidos

- autenticación, registro e invitaciones
- dashboard
- disciplinas y grados
- grupos y horarios
- alumnos, matrículas, graduaciones y documentos
- preinscripciones
- sesiones, asistencia y check-in
- progreso y seguimiento
- tarifas, cuotas, pagos, justificantes y recibos
- configuración y ejecución de avisos de cobro
- comunicaciones
- material, variantes y pedidos
- notificaciones
- usuarios/roles
- configuración del club
- perfil y push Android
- diagnóstico técnico
- Certification Runner E2E para Dirección

## Ruta única de escritura

`UI → repository → backend.mutate() → app_mutate_v160 → respuesta versionada → lectura → render`

Los formularios esperan la respuesta del backend antes de cerrarse. Los errores permanecen visibles.

## Desarrollo local sin consumir Netlify

Requisitos: Node.js 20 o superior.

```bash
npm run dev
```

Después abrir la URL local que muestre el servidor (por defecto `http://127.0.0.1:4173`).

El frontend local se conecta al mismo Supabase configurado en `web/config.js`. Esto permite probar el sistema completo antes del único deploy final.

## Verificación estática y build

```bash
npm test
npm run build
```

`npm run build`:
1. ejecuta los controles de arquitectura y contrato;
2. genera `dist/`;
3. sincroniza el mismo runtime con `android/app/src/main/assets/www`;
4. compara hashes para evitar divergencias Web/Android.

## Certificación E2E

Iniciar sesión con un usuario `direccion` y abrir **Certificación E2E**.

El runner genera datos con prefijo `E2E_RC1_`, recorre operaciones reales contra Supabase/PostgreSQL, vuelve a leer los registros y al final verifica persistencia tras logout/login.

No ejecuta automáticamente la generación masiva de cuotas ni cobros reales, porque `cuotas.generar` puede afectar registros legítimos del club. Esas dos funciones están implementadas, pero se comprueban de forma controlada en el smoke final.

## Netlify

Netlify no se utiliza como entorno iterativo. La RC está preparada para un único despliegue final después de superar la certificación local contra Supabase.

Véase `DEPLOY_FINAL.md`.
