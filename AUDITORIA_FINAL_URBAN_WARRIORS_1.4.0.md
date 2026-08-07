# Auditoría final técnica — Urban Warriors 1.4.0

## Resultado

La versión 1.4.0 supera las comprobaciones locales de sintaxis, construcción, contratos frontend↔RPC y circuitos operativos. No se incluyen datos demo en producción.

La certificación contra el proyecto Supabase real requiere aplicar la migración 009 y ejecutar la matriz manual indicada al final; ningún análisis local puede sustituir las políticas RLS, Auth y Storage del entorno desplegado.

## Correcciones críticas

- El registro público crea una **preinscripción pendiente**, no un socio prematuro.
- El socio se crea o actualiza dentro de una transacción al aprobar la solicitud.
- Para menores se vincula el tutor; para adultos se vincula el perfil autenticado.
- La aprobación valida disciplina, grupo, tarifa y plazas disponibles.
- Se añade lista de espera con notificación a la familia.
- Se evita duplicar solicitudes activas para la misma persona y disciplina.
- Los formularios cierran, muestran confirmación y recargan Supabase tras guardar.
- Se añade diagnóstico técnico `app_diagnostico_final`.
- Se validan 31 contratos RPC entre JavaScript y las migraciones SQL.

## Matriz técnica

| Circuito | Código | Contrato SQL | Persistencia diseñada | Dependencia externa |
|---|---:|---:|---:|---|
| Registro adulto/tutor | OK | OK | Preinscripción | Supabase Auth |
| Aprobación y alta socio | OK | OK | Transaccional | RLS real |
| Lista de espera | OK | OK | Sí | RLS real |
| Alta directa alumno | OK | OK | Transaccional | RLS real |
| Disciplinas y grados | OK | OK | Sí | RLS real |
| Grupos y múltiples horarios | OK | OK | Transaccional | RLS real |
| Sesiones y asistencia | OK | OK | Sí | RLS real |
| Tarifas y cuotas | OK | OK | Sí | Funciones SQL |
| Cobros y justificantes | OK | OK | Sí | Storage privado |
| Publicaciones/eventos con imagen | OK | OK | Sí | `club-public-media` |
| Material/variantes/pedidos | OK | OK | Sí | Storage |
| Perfil/progreso/documentos | OK | OK | Sí | `member-documents` |
| Notificaciones internas | OK | OK | Sí | Supabase |
| Renovación de sesión | OK | N/A | Sí | Supabase Auth |
| Push | Preparado | Preparado | Token/dispositivo | Firebase pendiente |

## Pruebas ejecutadas

- `npm test`
- `npm run build`
- `node --check web/js/app.js`
- `node --check web/js/data-store.js`
- validación JSON de `package.json`
- 31 contratos RPC verificados
- 15 circuitos finales verificados por código y migraciones

## Matriz de aceptación en producción

Después de aplicar 009 y publicar el parche:

1. Registrar adulto: debe quedar en preinscripciones, no en socios.
2. Registrar tutor/menor: debe quedar en preinscripciones y vincularse al aprobar.
3. Pasar a lista de espera y comprobar notificación.
4. Aprobar y comprobar socio, disciplina, grupo, tarifa y notificación.
5. Alta directa y edición de alumno.
6. Crear y editar grupo con dos horarios.
7. Crear sesión y guardar asistencia.
8. Crear tarifa, generar cuota y registrar cobro.
9. Adjuntar justificante y validarlo/rechazarlo.
10. Crear publicación y evento con imagen.
11. Crear material con imagen, variante y pedido.
12. Subir documento y registrar progreso.
13. Cerrar sesión, entrar desde otro navegador y verificar persistencia.
14. Ejecutar `select public.app_diagnostico_final('11111111-1111-4111-8111-111111111111');` como dirección.

Firebase, Cron y APK firmado se realizan después de aprobar esta matriz.
