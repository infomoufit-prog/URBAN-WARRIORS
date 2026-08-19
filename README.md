# KOMBAX / Urban Warriors · RC13 build 20030

Candidata local construida sobre build 20029. Mantiene continuidad Android y amplía la arquitectura multiclub con privacidad real por monitor.

- versión: `2.0.0-rc.13`;
- Android `applicationId`: `com.urbanwarriors.app`;
- Android `versionCode`: `20030`;
- fuente canónica: `/web`;
- `dist` y `android/app/src/main/assets/www` se regeneran con `npm run build` y deben ser idénticos.

## Bloques actuales

- 037–050: backend KOMBAX ya aplicado/verificado en el remoto durante esta sesión.
- 051: aplicado/verificado 9/9.
- 052: preflight 4/4 completado; migración pendiente.
- 053–056: pendientes de aplicación remota.
- 057: ámbitos de trabajo, privacidad por monitor y cartera financiera diferenciada, implementada localmente y pendiente de Supabase.

## Build 20030

Añade:
- varios monitores y alumnos/grupos compartidos mediante ámbitos;
- `Mis alumnos` seguro sin ficha administrativa completa;
- `Mis grupos` limitado por backend;
- `Mi cartera` con niveles `none/status/portfolio/collect/receipts`;
- permisos independientes de contacto, asistencia y seguimiento;
- documentos/recibos separados del acceso deportivo;
- administración `Ámbitos y privacidad` para Gestor/Coordinación;
- hardening de reservas, series, asistencia, seguimiento, graduación y mutaciones de sesiones.

Conserva todas las capacidades 20028/20029 de identidad KOMBAX, Social, scroll/feed, multimedia, Showcase, rojo sangre y Administración KOMBAX.

## Validación local

```bash
npm test
npm run build
npm run android:preflight
```

Resultados de esta entrega:
- tests: PASS;
- build: PASS;
- `71 archivos · web = dist = Android`;
- Android preflight: 3/5 esperado sin `google-services.json` real ni `keystore.properties`/JKS.

## Orden obligatorio para continuar

1. Supabase: continuar desde **migración 052**.
2. Completar 052 → 056.
3. Ejecutar 057 con su preflight/verify/test.
4. QA local real con Gestor, Monitor A, Monitor B y alumnos/grupos separados.
5. Solo después GitHub/Netlify.
6. Android: incorporar Firebase/JKS local, generar APK Release, validar actualización y generar AAB.

Runbook vigente: `SUPABASE_KOMBAX_RC13_20030_RUNBOOK.md`.
