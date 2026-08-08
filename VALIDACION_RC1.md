# Validación de la RC1

## Ejecutado en el entorno de construcción

- grafo de imports ES resuelto;
- no reutilización de `UW_STORE`;
- ausencia de modo demo paralelo;
- única puerta de mutación versionada;
- contrato validado antes de escribir;
- respuesta validada por versión, operación y `request_id`;
- formularios con `submit` directo y bloqueo de doble envío;
- service worker sin caché del runtime;
- operaciones de repositorio dentro del contrato;
- cobertura completa de las 37 operaciones `app_mutate_v160` en el frontend;
- Android `2.0.0-rc.1 / 20001`;
- runtime ES Modules servido por origen HTTPS virtual en Android;
- igualdad de Web → `dist` → Android mediante hashes.

## Lo que NO se puede certificar desde este entorno

Este entorno no dispone de acceso de red utilizable al proyecto Supabase ni de las credenciales del usuario Dirección. Por tanto, no se declara E2E real ni producción certificada desde aquí.

La aplicación incorpora **Certificación E2E** para ejecutar esa comprobación contra el Supabase real desde el navegador local antes de gastar un deploy de Netlify.

## Alcance del runner E2E

Realiza, con datos identificables `E2E_RC1_*`:

- contrato + probe + diagnóstico;
- disciplina: crear, leer, editar, releer;
- grado: crear y leer;
- grupo + horario: crear y leer;
- tarifa: crear y leer;
- alumno + matrícula: crear y leer;
- sesión: crear y leer;
- asistencia: guardar y leer;
- seguimiento: guardar y leer;
- comunicación: crear y leer;
- material + variante: crear y leer;
- logout/login y lectura posterior;
- desactivación/archivo de datos de prueba cuando el contrato lo permite.

No genera cuotas masivas ni registra pagos reales automáticamente para evitar alterar contabilidad legítima.
