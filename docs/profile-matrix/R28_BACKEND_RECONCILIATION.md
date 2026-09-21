# R28 · Reconciliación backend vivo

El ZIP fuente R27 termina localmente en migraciones 194/195. Al iniciar R28, el Supabase principal ya contenía tres migraciones R28 aplicadas el 30/08/2026. R28 no las duplicó: se alineó el frontend/paquete con ese contrato vivo.

Durante el cierre R32 se consultó `supabase_migrations.schema_migrations` y se confirmó que Supabase conserva también el array `statements` histórico exacto de las tres migraciones:
- 20260830221459 · `kombax_profile_capability_foundation_20101_r28`
- 20260830221550 · `kombax_profile_professional_spectator_mutations_20101_r28`
- 20260830222259 · `kombax_profile_capability_advisor_hardening_20101_r28`

Estado comprobado:
- tipos directos: competidor, marca, federacion, espectador, profesional;
- especialidades: entrenador, representante_manager, medico_sanitario, arbitro_juez, promotor_organizador;
- RLS activa en tablas privadas nuevas;
- tablas privadas sin DML directo para `anon`/`authenticated`;
- RPC sensibles v196 requieren sesión/gestión del perfil;
- `anon_execute=false` en RPC sensibles auditados.

Nota de reproducibilidad: los archivos SQL 196-198 no formaban parte del ZIP R27 ni fueron generados localmente durante la reconciliación inicial. Su contenido histórico exacto permanece en la tabla de migraciones del Supabase principal y fue verificado durante R32. No se ha inventado ni reescrito ese historial en el paquete.
