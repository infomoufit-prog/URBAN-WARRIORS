# Migraciones Supabase — Fase 1

- Aplicadas en esta fase: **0**.
- No se identificó una necesidad justificada de modificar el esquema para permitir múltiples roles; la relación única `(club_id, perfil_id, rol)` ya admite roles simultáneos.
- Las relaciones familiares existentes se consultan por `tutores_socios.tutor_perfil_id`, sin mutar la tabla.
- No se realizó ningún cambio de RLS ni se elevó autorización alguna.
- Pendiente de auditoría live por perfiles reales: políticas RLS y permisos de lectura de tutores, fichas e información económica.
- Las migraciones r262/r263 sí están aplicadas en la base remota con anterioridad; su DDL reproducible no se ha recuperado ni incorporado como si fuese nuevo. Deben conciliarse en la fase 2.
