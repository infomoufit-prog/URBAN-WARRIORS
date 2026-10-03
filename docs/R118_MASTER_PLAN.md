# KOMBAX R118 — Plan maestro auditable

Base de restauración: `pilot-20176-before-r118`.
Rama de trabajo: `r118-identity-pilot`.

Fases:
0. Reconciliar GitHub/Supabase/Netlify.
1. Fijar contrato R118.
2. Auditar exclusividades, perfiles, descubrimiento, verificaciones, entitlements y onboarding.
3. Desactivar exclusividad R100 manteniendo compatibilidad.
4. Garantizar Perfil Social canónico y facetas personales.
5. Fortalecer credenciales profesionales, declaración legal y publicación selectiva.
6. Corregir alta directa de Club piloto.
7. Validar código + email para alumnos/familias y equipo.
8. Unificar ciclo de notificaciones accionables.
9. Evitar duplicados en Discovery mediante agregación por persona.
10. Ejecutar QA de matrices y regresión.
11. Alinear web/dist/Android y versionar.
12. Fast-forward de main, verificar deploy y empaquetar ZIP acumulativo.

Regla de control:
- cada fase genera un commit identificable;
- no se declaran pruebas no ejecutadas;
- no se envían correos reales ni se crean usuarios/Clubes ficticios;
- cualquier contradicción nueva reabre la fase correspondiente antes de avanzar.
