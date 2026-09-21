# KOMBAX RC13 · BUILD 20030 · INFORME DE IMPLEMENTACIÓN

Fecha: 2026-08-17
Base: build 20029 IMPLEMENTED
Objetivo: privacidad real para clubes con varios monitores, alumnos compartidos y capacidades financieras diferenciadas.

## 1. Problema confirmado en el baseline

El backend histórico tenía controles de grupo para ciertas operaciones, pero el helper `puede_ver_socio()` y varias políticas/RPC reutilizaban la condición de monitor de forma demasiado amplia. Eso podía convertir una relación deportiva en acceso indirecto a superficies administrativas como la fila completa del socio, documentos o recibos.

La solución 20030 no consiste en ocultar menús: **el aislamiento se aplica en PostgreSQL/RLS/RPC** y la UI consume proyecciones mínimas.

## 2. Arquitectura 057

### Ámbitos

Nuevas tablas:
- `club_ambitos_trabajo`
- `club_ambito_equipo`
- `club_ambito_socios`
- `club_ambito_grupos`

Un ámbito representa una cartera operativa dentro de un club. Puede modelar un monitor, equipo, sede o división. La relación es muchos-a-muchos: un alumno/grupo puede estar en más de un ámbito. Solo puede existir un ámbito principal activo por alumno.

### Administración

Dirección/Coordinación administran ámbitos mediante `app_kombax_ambito_mutate_v057`. No se conceden privilegios por email ni desde JavaScript.

### Monitor restringido

Los monitores sin otro rol elevado se consideran restringidos. Su alcance procede de:
1. alumnos asignados directamente;
2. alumnos de grupos asignados al ámbito;
3. compatibilidad temporal con grupos donde sean `monitor_principal_id`.

## 3. Separación de privacidad

`puede_ver_socio()` vuelve a significar acceso administrativo/familiar: titular, tutor, Dirección, Secretaría o Economía según la regla existente. El monitor usa helpers 057 solo en superficies deportivas explícitas.

Consecuencias:
- no SELECT de la fila administrativa completa `socios` por ser monitor;
- documentos de socio y `member-documents` no se abren por acceso deportivo;
- recibos no heredan `puede_ver_socio` deportivo;
- asistencia, seguimiento, graduaciones, reservas, grupos y series se autorizan con guards específicos.

## 4. Finanzas por ámbito

`club_ambito_equipo.finance_level` admite:
- `none`
- `status`
- `portfolio`
- `collect`
- `receipts`

`app_kombax_mi_cartera_v057()` devuelve únicamente alumnos dentro de los ámbitos del monitor y oculta importes/recibos cuando el nivel no lo permite.

`app_kombax_monitor_cobro_v057()` valida cuota, alumno, ámbito, nivel, saldo, método e importe antes de registrar el pago. El monitor no recibe acceso DML directo a las tablas financieras.

## 5. Permisos operativos

Por asignación de equipo:
- `ver_contacto`
- `gestionar_asistencia`
- `gestionar_seguimiento`
- `responsable`

Asistencia requiere además que sesión, grupo y matrícula correspondan al alcance autorizado. Seguimiento/graduación requiere el permiso específico.

## 6. Sesiones

Se endurecen:
- reserva/lectura de sesión;
- lectura de series recurrentes;
- `app_guardar_asistencia`;
- `app_guardar_seguimiento`;
- `app_registrar_checkin`;
- `app_registrar_graduacion`;
- `app_generar_sesiones_recurrentes`;
- operaciones de serie/excepción a través de `app_mutate_v160`.

El wrapper anterior se conserva como `app_mutate_v160_pre_work_scopes_057` para rollback y compatibilidad.

## 7. Frontend

### Gestor/Coordinación
Nueva sección **Ámbitos y privacidad**:
- crear/editar ámbito;
- añadir/quitar equipo;
- nivel financiero;
- contacto/asistencia/seguimiento;
- añadir/quitar alumnos;
- marcar ámbito principal;
- añadir/quitar grupos.

### Monitor
- `Mis alumnos`: RPC segura, sin expediente ni documentos.
- `Mis grupos`: RLS/scoping backend.
- `Mi cartera`: vista adaptada a `finance_level`.
- navegación móvil con acceso directo a `Mis alumnos`.

## 8. Versionado

- Web: build 20030.
- Service Worker/cache: 20030.
- Android `versionCode`: 20030.
- Android `applicationId`: `com.urbanwarriors.app` sin cambios.
- Release contract 056: build 20030 porque 056 aún no estaba aplicado al remoto al crear esta release.

## 9. Validación ejecutada

- Suite histórica + 20028 + 20029 + nueva `test-kombax-20030-monitor-scopes.mjs`: PASS.
- `npm run build`: PASS.
- Sincronización: `71 archivos · web = dist = Android`.
- Sintaxis de módulos modificados: PASS.
- Auditoría estática SQL 057/rollback: PASS.
- Smoke local: HTTP 200; `app.js?v=20030`, `kombax-premium.css?v=20030`.
- Secretos: no se incluyen `.env`, `google-services.json`, `keystore.properties`, JKS/keystore.
- Android preflight: 3/5 por secretos locales deliberadamente ausentes.

## 10. Estado remoto real

- 037–050: aplicadas/verificadas previamente.
- 051: aplicada y verify 9/9 TRUE.
- 052: preflight 4/4 TRUE; **migración todavía pendiente**.
- 053–056: pendientes.
- 057: código implementado; **no aplicar antes de 056**.

No declarar 057 certificada hasta ejecutar verify y prueba transaccional real con, como mínimo, Gestor/Coordinación, Monitor A, Monitor B, alumnos/grupos separados y varios niveles financieros.
