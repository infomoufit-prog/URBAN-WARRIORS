# FASE 4 · KOMBAX RC13 build 20.093 · Events Social & Viral

## Objetivo
Convertir KOMBAX Eventos en un motor de descubrimiento y adquisición sin duplicar Social ni abrir todavía el perfil Espectador. Esta fase parte exclusivamente de 20.092 y mantiene `Mi Club > Eventos` como dominio privado independiente.

## Plan previo aprobado antes de tocar código
1. Reconciliar el backend real: aplicar y verificar 159, 160 y 161 en Supabase antes de construir nuevas funciones.
2. Mantener tablas de Eventos en arquitectura RPC-only: RLS activo, acceso directo revocado y EXECUTE mínimo por función.
3. Añadir engagement reutilizable (`Me interesa` / `Asistiré`) sin activar todavía la cuenta Espectador.
4. Crear puente Social por referencia: la publicación Social conserva sus cuotas, moderación y audiencia; Eventos sigue siendo la fuente de verdad.
5. Crear landing pública por `slug` para enlaces/QR antes del login.
6. Crear KOMBAX Visual Engine local, sin API key: evento, Fight Card y resultado en 1080×1080 y 1080×1920.
7. Crear QR local escaneable, sin servicios externos.
8. Añadir motion/animaciones y fondos con `prefers-reduced-motion`.
9. Aplicar migración Fase 4 y hardening de índices al backend real.
10. Ejecutar Security/Performance Advisors, regresión histórica, build determinista y empaquetado completo.

## Riesgos controlados
- No saltarse cuotas/moderación de Social.
- No exponer alumnos privados o eventos internos.
- No habilitar Espectador antes del gate edad/privacidad.
- No introducir fetch directo desde módulos UI.
- No depender de APIs de imágenes/QR.
- Mantener Android/PWA compatibles con Canvas y fallback de rutas redondeadas.

## Criterios de cierre
- Migraciones 159–163 registradas y verificadas en Supabase principal.
- Todas las tablas nuevas con RLS y sin DML directo para anon/authenticated.
- Mutadores Events no ejecutables por anon.
- `health` productivo = build 20093.
- QA 20090/20091/20092/20093 + suite histórica PASS.
- `npm run build` PASS y web = dist = Android.
- ZIP autocontenido con continuidad y hashes.
