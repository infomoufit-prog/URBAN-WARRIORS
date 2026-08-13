# Changelog

## Baseline recovery 023 — desplegado y validado

- Detectado gateway de producción distinto del RC10 final.
- Localizada la copia íntegra RC10 en `app_mutate_v160_v166`.
- Añadida migración reversible para recuperar el gateway sin modificar datos.
- Añadido test estático específico y punto de rollback.
- Ejecutado en Supabase real con resultado 12/12 OK.
- Certificación E2E real superada: 19/19.

## 2.0.0-rc.10

- Base estable recibida y congelada como punto de retorno.
