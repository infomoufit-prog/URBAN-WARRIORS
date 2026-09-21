# KOMBAX R72 · Release Notes · build 20123

Fecha de cierre: 14/09/2026  
Base acumulativa: R71 / build 20122  
Estado: **Pilot Freeze Candidate**.

## Cambios funcionales
- Showcase incorpora **ampliaciones de catálogo +25 productos por 8 EUR / 30 días**, renovables y acumulables. No activan Commerce.
- Capacidades incluidas conservadas: Club Básico 15, Club Premium 25, Brand Start 25, Brand Growth 100; Enterprise permanece ilimitado.
- Archivar libera capacidad y conserva ficha, reputación e historial.
- Eliminar es ahora seguro: borrado físico solo sin historial; con pedidos/reseñas se retira la ficha conservando trazabilidad.
- Showcase incorpora valoraciones 1–5, texto, fotografías, Compra verificada, respuesta del vendedor y reportes.
- KOMBAX Events incorpora Comunidad antes/durante/después del evento: comentarios, respuestas, media, valoraciones y distintivo **Asistió al evento** derivado del check-in real.
- Centro del evento incorpora Comunidad y valoraciones para el organizador, con respuesta y reporte; no permite borrar unilateralmente críticas legítimas.
- Moderación de reputación queda reservada a KOMBAX plataforma.

## Contratos y documentación
- Marketplace: políticas QA versionadas a `1.2-r72-qa`.
- Events/Ticketing: acuerdo QA versionado a `1.3-r72-qa`.
- Matriz comercial, referencia de precios, términos/privacidad y PDF de precios actualizados.
- Los documentos siguen marcados como borrador QA y requieren revisión jurídica antes del lanzamiento público.

## Backend
- 11 migraciones R72 aplicadas y conservadas en `supabase/migrations/` con las mismas versiones que Supabase live.
- Esquema privado `kombax_reputation` con 4 tablas y acceso mediante RPC controladas.
- 6 índices de cobertura añadidos tras la auditoría de rendimiento; comprobación final R72: 0 FKs sin índice de cobertura.
- `health` activo en Supabase Edge Functions: v30, build 20123.

## QA
- Suites R72: **106/106**.
- Build: **206 archivos; web = dist = Android**.
- Android preflight: **4/5**; falta `android/keystore.properties` local.
- Android debug: no compiló porque el entorno no resolvió `services.gradle.org`; no se generó APK/AAB nuevo.
- Escaneo de credenciales del paquete: PASS.

## No realizado por política de release
No se ha desplegado frontend/Netlify, no se ha hecho push a GitHub y no se ha publicado Google Play. SaaS Billing de KOMBAX sigue fuera de alcance y desactivado.
