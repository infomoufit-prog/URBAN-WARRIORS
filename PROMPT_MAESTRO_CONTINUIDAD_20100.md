# PROMPT MAESTRO DE CONTINUIDAD · KOMBAX RC13 build 20.100

Trabaja a partir de `KOMBAX_RC13_build_20100_KOMBAX_BRAND_HEROES_WITH_LOCAL_SIGNING` como fuente de verdad.

## Estado actual
- Brand Heroes definitivos en Social, Events y Showcase.
- único logo oficial: `KOMBAX_BRAND.symbol` / `assets/brand/kombax-symbol-white.png`.
- no introducir lobos, escudos ni logos alternativos como marca KOMBAX.
- Events: `FROM HYPE TO HISTORY` + `EL ESPECTÁCULO NO EMPIEZA EN EL RING. EMPIEZA AQUÍ.`.
- 20.099 mantiene álbum oficial: 15 fotos y 5 vídeos HD de máximo 60 s.
- 20.098 mantiene Large Format.
- 20.097 mantiene aislamiento Urban Warriors/Federación.
- no mezclar KOMBAX Events con Mi Club > Eventos.
- Spectator sigue deshabilitado.

## Regla de trabajo
Antes de cualquier fase nueva: plan específico (alcance, riesgos, migraciones/archivos, QA, criterios de cierre). Implementar sobre 20.100, ejecutar regresión completa y entregar ZIP autocontenido con continuidad.

## Backend
20.100 no añade migraciones. Las migraciones Events 175/176 de 20.099 siguen siendo la base productiva. Si una futura fase toca backend, aplicar al Supabase real y verificar ACL/RLS/RPC/advisors antes de entregar.

## Android
- applicationId: `com.urbanwarriors.app`.
- versionCode 20100.
- JKS real incluido en `LOCAL_RELEASE_SIGNING/` por petición del propietario.
- no crear otro keystore.
- contraseñas nunca dentro del ZIP.

## Siguiente QA recomendado
1. validar los tres heroes en navegador desktop y móvil;
2. comprobar Social / Events / Showcase con datos reales de QA;
3. crear primer KOMBAX Evento completo tras deploy compatible;
4. validar portada, Fight Card, álbum previo/evento/posterior, tickets externos y resultados;
5. después, APK signed y AAB desde exactamente la misma fuente.
