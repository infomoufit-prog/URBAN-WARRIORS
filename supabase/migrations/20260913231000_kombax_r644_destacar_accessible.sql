-- KOMBAX R64.4 - Destacar accesible
-- Compensating, idempotent pricing update. Keeps promotion engine and frequency caps unchanged.

insert into kombax_commercial.runtime_config_r64(config_key,value,description,updated_at)
values (
  'content_promotion',
  '{"7":300,"15":500,"30":800,"max_promoted_events_per_user_day":2,"same_event_frequency_hours":72,"no_consecutive_promotions":true}'::jsonb,
  'Único servicio Destacar para Events/Showcase con amplificación Social. Precios accesibles R64.4: 3/5/8 EUR.',
  now()
)
on conflict (config_key) do update set
  value=excluded.value,
  description=excluded.description,
  updated_at=now();
