# Urban Warriors 2.0.0-rc.10 · FINAL MVP

RC10 es la candidata de congelado funcional del MVP. Conserva la arquitectura estable de RC9 y añade el último paquete de producto: notificaciones escalables, sesiones recurrentes, Comunidad temporal, perfil/avatar, cierre de Finanzas, preparación push, ayuda/manuales y consentimiento legal versionado.

## Núcleo estable

- Backend: `1.6.0`
- Schema epoch: `160`
- Gateway único: `app_mutate_v160`
- Diagnóstico RC10: `app_diagnostico_final_v166()` dentro de la app (Gestor)
- Diagnóstico instalable desde SQL Editor: `app_diagnostico_instalacion_v166()`

## Roles

- **Gestor de la app**: máximo nivel (`direccion` internamente).
- **Coordinación**: gestión operativa amplia, sin herramientas técnicas de máximo nivel.
- **Secretaría**
- **Economía / Tesorería**
- **Comunicación**
- **Monitor**
- **Familia / Alumno**

## Novedades RC10

- Notificaciones agrupadas y lectura masiva.
- Preferencias push por categoría.
- Series semanales de sesiones + excepciones.
- Comunidad: 3 publicaciones/mes usuario, 5/mes equipo, vídeo <=15 s, retención 30 días.
- Perfil privado con fotografía.
- Estado de cuenta y métricas de Tesorería.
- Manual de usuario + manual de equipo + ayuda interna.
- Cartel de difusión solo para Gestor/Coordinación/Secretaría.
- Condiciones, privacidad, Comunidad y derechos de imagen versionados.
- Android preparado para routing de push y sincronización de token.

## Migración

Ejecutar **una sola vez**, después de RC9:

`SQL_EJECUTAR_RC10_022.sql`

El resultado final del SQL debe mostrar **12 controles `OK`**.

## Prueba local

```bash
npm install
npm test
npm run build
npm run dev
```

## Push

El repositorio no contiene credenciales privadas. La preparación de código está incluida, pero la certificación final requiere Firebase real, secretos de Supabase, Edge Functions desplegadas/programadas y una prueba en Android físico con la app cerrada. Ver `PUSH_PRODUCCION_CHECKLIST.md`.

## Documentación

- `AUDITORIA_MAESTRA_RC10_FINAL.md`
- `INFORME_RC10_FINAL_MVP.md`
- `VALIDACION_RC10_FINAL.md`
- `PUSH_PRODUCCION_CHECKLIST.md`
- `DEPLOY_FINAL.md`
- `web/assets/docs/Manual_Usuario_Urban_Warriors.pdf`
- `web/assets/docs/Manual_Equipo_Urban_Warriors.pdf`
