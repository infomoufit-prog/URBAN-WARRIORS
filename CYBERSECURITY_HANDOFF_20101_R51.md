# CYBERSECURITY HANDOFF — R51

- R51 reutiliza los buckets, RLS y resolutores de media existentes; no introduce un bucket público nuevo.
- La portada es un asset separado y no altera el vídeo original.
- El normalizador de presentación no es invocable directamente por `anon` ni `authenticated`.
- La resolución de portada de Events aplica el mismo modelo de acceso que el asset de evento.
- El secret scan no encontró credenciales privadas incrustadas. La referencia `SUPABASE_SERVICE_ROLE_KEY` encontrada en una Edge Function heredada es una lectura de `Deno.env`, no un secreto hardcodeado.
- La deuda global de Security/Performance Advisors del proyecto permanece fuera del alcance R51 y no debe declararse cerrada.
