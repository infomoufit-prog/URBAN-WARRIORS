# Migration List · KOMBAX 20.101 R35

Nuevas migraciones locales incluidas y aplicadas al proyecto Supabase conectado:

1. `218_kombax_event_centric_preparation.sql`
   - vínculo preparación ↔ inscripción
   - roster unificado de preparación
   - pesaje oficial de evento
   - separación organizador/histórico privado

2. `219_kombax_event_centric_preparation_privacy_hardening.sql`
   - elimina acceso implícito de monitores al histórico
   - restringe gestión privada del club presentador a dirección/coordinación
   - mantiene equipo por grants explícitos

Versiones live:
- `20260903232924`
- `20260903233155`
