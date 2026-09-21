# CHANGELOG · KOMBAX 20.101 R38

## KOMBAX Assist y KOMBAX Migrations separados
- **KOMBAX Assist** queda como soporte estándar: contacto por `soporte@kombax.es` y chat guiado únicamente cuando soporte lo activa para un caso que requiere interacción.
- El cliente no puede autoactivar ese chat desde la UI ni reutilizando la RPC histórica v213.
- **KOMBAX Migrations** pasa a ser un canal visible e independiente, de acceso directo, con chat y carga de documentos en la misma experiencia.

## Migración asistida de datos
- Admite CSV, XLS, XLSX, PDF, JPEG, PNG y WEBP dentro de los límites del backend.
- Permite varias cargas dentro del mismo caso de migración.
- Analiza por lotes, reutiliza resultados ya extraídos y prepara vista previa.
- No ejecuta importaciones automáticamente: la confirmación humana sigue siendo obligatoria.

## Economía IA
- Ledger privado por turno y controles de coste por plan/caso/período.
- Enrutamiento privado con modelo económico por defecto y escalado controlado.
- Límites por turnos, documentos, MB y detalle visual.
- La UI cliente muestra cupos comprensibles, no nombres de modelos, tokens ni costes internos.

## Backend y seguridad
- Migraciones 227–234 incluidas.
- 232 separa el permiso de consumo: Assist exige chat guiado activo; MIGRATION queda exento de esa activación previa.
- 233 bloquea la autoactivación customer-side y revoca `authenticated` sobre la mutación histórica v213.
- 234 añade índices de cobertura para las nuevas FKs señaladas por el advisor de rendimiento.
- Edge Function `kombax-assist-r38` procesa chat/multimodal y persiste el ledger; no autoimporta datos.

## Plataforma
- PWA cache `20101r38` / `media-r38`, preservando continuidad R37.
- Build 20.101 mantiene `applicationId=com.urbanwarriors.app`, `versionCode=20101`, `versionName=2.0.0-rc.13`.
