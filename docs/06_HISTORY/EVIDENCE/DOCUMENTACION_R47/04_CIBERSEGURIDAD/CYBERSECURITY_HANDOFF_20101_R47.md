# Cybersecurity handoff · R47

## Superficie nueva
- Preferencias privadas triestado de relevancia.
- Reglas privadas de audiencia por perfil/tipo.
- Feed de ranking v237.
- Edición de visibilidad de una publicación existente.
- Compatibilidad de privacidad entre audiencia y bucket multimedia.

## Controles verificados
- RLS activo en las tres tablas internas R47.
- `anon` y `authenticated` sin lectura/escritura directa en esas tablas.
- Feed/config/mutación R47: authenticated EXECUTE=true y anon=false.
- Mutación viva contiene `kombax.social.preferencia` y `kombax.social.visibilidad`.
- Frontend impide transición pública/restringida incompatible con el bucket de la media.
- Secret-pattern scan de runtime/source activo: 413 archivos, 0 hallazgos.

## Límites
El pattern scan no es un pentest. No se obtuvo una ejecución nueva fiable de Security/Performance Advisors durante este cierre. También falta E2E con dos cuentas reales para demostrar que no existe fuga entre audiencias y buckets en un navegador/dispositivo real.

## Gate
Mantener HOLD de datos personales reales hasta QA manual + advisors/revisión backend global + aprobación de ciberseguridad.
