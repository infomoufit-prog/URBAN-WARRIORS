# Validación RC9 final

Fecha de empaquetado: 2026-08-10.

## Resultado automático

- `npm test`: **PASS**.
- Arquitectura 2.0 / gateway único: **PASS**.
- Contrato de operaciones RC8 preservado: **62/62**.
- Regresiones RC4, RC5, RC6, RC7 y RC8: **PASS**.
- Prueba específica RC9 Gestor + Coordinación: **PASS**.
- Android: `2.0.0-rc.9` / `versionCode 20009`.
- `npm run build`: **PASS**.
- Paridad `web = dist = android assets`: **34/34 archivos**.
- Sintaxis JavaScript: **PASS**.

## Cobertura RC9

La prueba específica comprueba:

- `direccion` se muestra como **Gestor de la app**.
- existe el nivel visible **Coordinación**;
- Coordinación recibe permisos operativos en catálogo, alumnos, finanzas, comunicaciones, sesiones, documentos y configuración;
- invitaciones y certificación siguen exclusivas del Gestor;
- Coordinación comparte navegación operativa pero no Diagnóstico/E2E;
- equipo e invitaciones colapsan los permisos auxiliares en un único rol visible;
- SQL 021 no concede nunca `direccion` a Coordinación;
- RC8 queda encapsulado y el gateway público sigue siendo `app_mutate_v160`.

## Pendiente de certificación real

La migración 021 todavía debe ejecutarse en el Supabase real. Tras `Success`, debe probarse con una segunda cuenta una invitación real de **Coordinación** y confirmar visualmente que no aparecen Herramientas técnicas, creación de invitaciones ni botones `Eliminar todo`.
