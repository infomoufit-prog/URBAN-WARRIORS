# KOMBAX i18n · QA de activación de 8 idiomas

Fecha: 2026-09-15T22:05:41+02:00

## Estado automatizado

- Catálogo directo: **1.077/1.077 claves en ES, EN, FR, PT, IT, DE, TH y FIL**.
- Locales activos: **8/8**.
- Copy legacy directo: **2.580 frases por locale** para FR/PT/IT/DE/TH/FIL, sin fallback automático a la tabla EN.
- Public legal: **133 strings directas por locale no español**.
- Auth: **6 plantillas × 8 locales**.
- PWA: manifest específico para los 8 locales.
- Runtime software copy: **4.715/4.715 auditado; 0 unresolved**.
- System channels: **8/8 PASS**.
- `npm test`: **PASS**.
- Build: **PASS — 449 files; web = dist = Android**.
- Legal Gate: **PASS**.
- Android preflight: **4/5**, exclusivamente por firma local externa.

## Thai / documentos

El informe financiero dinámico intenta renderizado Thai Unicode mediante Noto Sans Thai cargada en runtime (URL configurable mediante `KOMBAX_THAI_FONT_URL`). No se incluye ningún archivo de fuente en el ZIP. Si la fuente no puede cargarse, el documento utiliza un fallback seguro para evitar PDF corrupto. Debe validarse reachability en staging/producción autorizada.

## Pendientes de release real

La activación técnica automatizada está cerrada. Antes de lanzamiento comercial deben recorrerse los 8 locales con cuentas/roles reales, desktop/mobile/PWA/Android, servicios Stripe/email/push y documentos generados. FR/DE requieren especial atención a longitudes y TH a tipografía/wrapping.
