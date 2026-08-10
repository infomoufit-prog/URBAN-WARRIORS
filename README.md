# Urban Warriors 2.0.0-rc.5 · Premium Media & Notifications

RC5 conserva la arquitectura estable y certificada de la línea 2.0 con una reconstrucción de experiencia visual y paridad de producto basada en las versiones anteriores de Urban Warriors.

## Principio de RC5

**No se toca la persistencia que ya funciona.**

Se mantienen el backend Supabase 1.6.0, RLS, Storage, Auth, `app_mutate_v160`, epoch 160 y la arquitectura modular de RC3. RC5 mantiene esa experiencia Premium y añade iconografía SVG, multimedia directa y centro de notificaciones conectado al backend existente.

## Novedades principales

- sistema visual Urban Warriors Premium oscuro;
- login/onboarding de marca;
- dashboards específicos por rol;
- navegación inferior móvil específica por rol;
- listados adaptativos: tabla desktop / cards móvil;
- catálogo deportivo visual;
- grupos con ocupación y horarios;
- preinscripciones en pipeline;
- comunicaciones tipo feed;
- material en catálogo de producto;
- Equipo e invitaciones;
- portal completo Familia/Alumno;
- selector de hijos/socios vinculados;
- asistencia, grado, próxima clase y cuotas como métricas;
- horarios y check-in;
- comunicar pago y solicitar material;
- solicitar otra disciplina/grupo y añadir menor;
- progreso, graduaciones, seguimiento y documentos visibles.

## Ruta de escritura

`UI → repository → backend.mutate() → app_mutate_v160 → respuesta → lectura → render`

No existe DML directo desde los módulos de UI.

## Desarrollo/certificación local

```bash
npm install
npm run build
npm run dev
```

Abrir `http://127.0.0.1:4173` y ejecutar **Certificación E2E** con una cuenta Dirección antes de subir RC5 a Netlify.

## Documentación

- `INFORME_RC5_MEDIA_ICONOS_NOTIFICACIONES.md` — mejoras RC5 y límites.
- `VALIDACION_RC5.md` — controles y certificación pendiente.
- `INFORME_RC4_PREMIUM.md` — base visual y paridad recuperada.
- `MATRIZ_PERMISOS.md` — permisos de UI derivados del backend.
- `DEPLOY_FINAL.md` — procedimiento de deploy único.
