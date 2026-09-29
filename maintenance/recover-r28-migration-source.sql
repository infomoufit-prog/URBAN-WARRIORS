-- READ-ONLY · KOMBAX R109
-- Recupera del historial autorizado de Supabase el SQL exacto de las tres migraciones R28 ausentes del ZIP.
-- NO ejecuta ni reaplica las sentencias devueltas.
select version, name, statements
from supabase_migrations.schema_migrations
where name in (
  'kombax_profile_capability_foundation_20101_r28',
  'kombax_profile_professional_spectator_mutations_20101_r28',
  'kombax_profile_capability_advisor_hardening_20101_r28'
)
order by version;
