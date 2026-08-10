# Validación · Urban Warriors 2.0.0-rc.5

## Ejecutado en el artefacto

- `node --check` en los módulos modificados: **OK**.
- `npm test`: **PASS**.
- contrato frontend: **37/37 operaciones** conocidas por `app_mutate_v160`.
- arquitectura sin `UW_STORE` ni DML directo: **PASS**.
- versión Android `2.0.0-rc.5 / 20005`: **PASS**.
- sistema SVG y navegación profesional: **PASS**.
- información técnica fuera de login/topbar/nav cotidiano: **PASS**.
- subida de imágenes de publicaciones/material conectada a `club-public-media`: **PASS estático**.
- límite 5 MB y MIME compatibles con el bucket: **PASS**.
- creación SQL de notificación al publicar: **verificada en migración existente**.
- audiencias `todos/familias/monitores`: **verificadas contra SQL**.
- lectura por usuario de notificaciones compartidas: **PASS estático**.
- badge + refresco al entrar + polling de nuevas notificaciones: **PASS estático**.
- Edge Function de programadas/FCM presente: **PASS estático**.
- migraciones 001→017: **idénticas a la base certificada**.
- `npm run build`: **PASS**.
- web = dist = Android: **33 archivos idénticos**.

## Pendiente de certificación real local

Antes de Netlify:

1. ejecutar el Certification Runner contra el Supabase real;
2. crear desde localhost una publicación de prueba con imagen;
3. verificar que la imagen queda visible después de recargar;
4. publicar `audiencia=todos` y confirmar aparición del aviso en la campana/bandeja;
5. si se necesita push con la app cerrada, comprobar aparte cron/Edge Function + Firebase en el proyecto real.

La RC5 no se declara production-ready hasta esas comprobaciones.
