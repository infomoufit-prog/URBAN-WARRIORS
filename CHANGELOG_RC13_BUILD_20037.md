# KOMBAX RC13 build 20037 — Release audit hardening

- Auditoría profunda de los cambios 20031–20036 antes de GitHub/Netlify.
- Corrige rutas del Manual interactivo contra permisos/navegación reales; Monitor ya no recibe Catálogo/Disciplinas.
- Propaga el tema premium del club al `body` para overlays: modales, formularios, diálogos legales y toasts.
- Extiende Premium Neon a Showcase, Eventos, Material/Tienda, acciones rápidas y superficies especializadas mediante tokens globales.
- Elimina copy genérico hardcodeado a Urban Warriors; conserva el tenant real y marcadores internos donde corresponde.
- Actualiza el flujo visible de equipo al modelo activo de código reutilizable → solicitud pendiente → validación Gestor/Coordinación.
- Añade verificadores SQL locales para 058 y 062 y conserva verificadores 059–061.
- Mantiene el manual interactivo y cartel KOMBAX genérico; los PDFs/galerías/cartel legacy quedan fuera del runtime.
- No requiere nueva migración Supabase: 058–062 fueron verificadas contra el backend real con 10/10 controles.
- Build/versionCode actualizado a 20037.
