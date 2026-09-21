# KOMBAX R72 · Rollback / Contención

R72 ya está aplicado en Supabase live. El rollback recomendado es **lógico, aditivo y conservador**, no destructivo, porque reseñas y comunidad pueden adquirir historial de usuario.

1. Desactivar `showcase_catalog_plus_25` en `kombax_commercial.service_catalog` y retirar su exposición UI si fuera necesario.
2. No borrar productos/reseñas/comentarios para recuperar capacidad: usar `archivado`, `fuera_capacidad`, `retirado` u ocultación moderada según corresponda.
3. Revocar temporalmente `EXECUTE` de RPC R72 de escritura ante un incidente; el esquema `kombax_reputation` ya impide acceso directo de `anon/authenticated`.
4. Retirar las políticas QA `1.2-r72-qa` / `1.3-r72-qa` y reactivar versiones previas solo si se revierte funcionalmente a R71.
5. Restaurar frontend R71/build 20122 desde su ZIP congelado si la regresión está en cliente.
6. No ejecutar `DROP TABLE` de `kombax_reputation` ni purgas masivas una vez existan aportaciones; cualquier eliminación debe seguir retención/legal y copia de seguridad.
7. `health` puede volver a la fuente R71 si se revierte la aplicación; el esquema R72 puede permanecer sin uso por ser aditivo.

Antes de un rollback real, exportar datos R72 y conservar evidencia de contratos, aceptaciones y auditoría. No revertir el historial de migraciones manualmente salvo procedimiento de recuperación controlado.
