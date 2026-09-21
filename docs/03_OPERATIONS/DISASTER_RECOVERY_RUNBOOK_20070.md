# KOMBAX 20070 · recuperación en Supabase Free

No se afirma disponer de recuperación punto en el tiempo. En el plan gratuito, el piloto exige exportaciones externas cifradas y simulacros propios.

## Copia

1. Definir `KOMBAX_DATABASE_URL` solo en la sesión segura del operador.
2. Ejecutar `scripts/backup-supabase-free.ps1 -OutputDirectory <ruta-segura>`.
3. Guardar `.dump`, manifiesto SHA-256, migraciones y código de Edge Functions fuera del proyecto Supabase.
4. Exportar también objetos de los buckets privados mediante una cuenta de servicio controlada; verificar recuentos y tamaños sin publicar enlaces firmados.

## Simulacro

1. Restaurar en una base aislada, nunca sobre LIVE.
2. Aplicar `pg_restore --clean --if-exists --no-owner --no-privileges` contra el destino aislado.
3. Ejecutar verificaciones de esquema, RLS, recuentos, funciones y referencias de Storage.
4. Documentar duración, resultado y hash del backup; destruir de forma segura el entorno aislado.
5. Marcar `backup_export` y `restore_drill` solo con evidencias independientes.

Objetivos iniciales de piloto: RPO máximo 24 h y RTO máximo 8 h. Deben ser aceptados formalmente antes de incorporar clubes reales.
