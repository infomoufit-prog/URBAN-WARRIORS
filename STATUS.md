# Estado del proyecto

## Estado actual

- Release activa de trabajo: **Release A — certificación RC10**.
- Código funcional: **sin modificar**.
- Pruebas locales: **superadas**.
- Supabase real: **migración 023 ejecutada; diagnóstico 12/12 OK**.
- Certificación E2E Gestor del backend: **19/19 OK, ejecutada desde la interfaz RC12 instalada**.
- Web/PWA publicada: **RC12 detectada; pendiente de restaurar RC10 y certificarla**.
- Android físico instalado: **RC12 detectada; RC10 pendiente de generar e instalar**.
- Producción: **sin cambios realizados**.

## Punto de retorno

El ZIP RC10 original, identificado en `BASELINE_RC10.md`, es el punto de retorno inmutable.

## Bloque permitido actualmente

Solo restauración y certificación funcional de RC10. El gateway RC10 ha sido validado mediante el E2E real desde RC12, pero esto no certifica la interfaz RC10. Faltan la restauración web, la APK RC10 y las comprobaciones manuales por rol antes de cerrar Release A.

## Bloque siguiente

Release B: safe area superior e inferior, aislada de Firebase, Supabase y las funciones de negocio.
