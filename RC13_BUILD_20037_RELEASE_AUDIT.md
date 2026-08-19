# Auditoría de release — RC13 build 20037

## Alcance
Revisión de los cambios acumulados 20031–20036 antes de GitHub/Netlify: avatar y perfiles Social, códigos de acceso reutilizables del club, Premium Neon global, Combat Social, Showcase, manual interactivo/cartel, PWA, Android, Supabase 058–062 y preparación de despliegue.

## Hallazgos reales corregidos
1. **Manual / Monitor**: el rol Monitor podía ver habilitado `Disciplinas y grados`, aunque `catalog` no forma parte de su navegación real. Se corrige y se añade una prueba que cruza las rutas del manual con las rutas realmente navegables por rol.
2. **Premium Neon / overlays**: modales, formularios, diálogos legales y toasts montados directamente bajo `<body>` no heredaban siempre el tema porque los selectores estaban acotados a `.app-shell`. Se sincroniza el tema activo al `body` y se tematizan esos overlays.
3. **Premium Neon / superficies especializadas**: Showcase, Eventos, Material/Tienda, acciones rápidas y algunos paneles especializados conservaban superficies o acentos fijos. Se conectan a los tokens globales del club, manteniendo independientes los colores semánticos de error/aviso/éxito.
4. **Multiclub / copy genérico**: quedaban textos de interfaz genérica hardcodeados a `Urban Warriors`. Se sustituyen por `KOMBAX`, `tu club` o el nombre dinámico del tenant. Se conserva `Urban Warriors` únicamente donde es el tenant real/demo o un marcador interno E2E.
5. **Alta de equipo**: una ayuda del acceso de equipo seguía describiendo la invitación individual antigua. Se actualiza al modelo activo: código reutilizable del club → solicitud pendiente → validación por Gestor/Coordinación → asignación del rol.
6. **Higiene SQL**: se añaden verificadores repo-locales para 058 y 062, completando la cadena de verificadores 058–062.
7. **Manual/cartel legacy en deploy**: el candidato local ya no contiene PDFs, galerías ni cartel antiguos. El inventario de despliegue debe eliminar también esos assets históricos del árbol de GitHub para impedir que Netlify los siga publicando por arrastre.

## Backend verificado
No se aplica migración nueva en 20037. El proyecto Supabase real fue comprobado con 10 controles independientes:
- helper y trigger de avatar Social 058;
- ausencia de invitaciones individuales 059 pendientes;
- tablas/RPC del sistema de códigos y solicitudes 060;
- RPC de tema público 061;
- guard de integridad de comentarios 062;
- profundidad Storage Social y Showcase corregida a 3 carpetas.

Resultado: **10/10 TRUE**.

## QA automatizada
- `npm test`: PASS.
- `npm run build`: PASS.
- regresión específica `test-kombax-20037-release-hardening.mjs`: PASS.
- `web = dist = android/app/src/main/assets/www`: 62/62/62, hashes idénticos.
- secretos/keystores/google-services reales en paquete: ninguno.
- manuales/carteles legacy en paquete: ninguno.
- caché/service worker: build 20037, sin referencias 20030–20036.

## Smoke local
HTTP 200 para:
- `/`
- `/js/app.js?v=20037`
- `/css/app.css?v=20037`
- `/assets/docs/Cartel_Descarga_KOMBAX_Club.png`
- `/service-worker.js`

## GitHub / Netlify
Repositorio identificado: `infomoufit-prog/URBAN-WARRIORS`, `main` actualmente en build 20020. El conector tiene permisos administrativos. El despliegue debe hacerse como commit atómico que replique el árbol local 20037, incluidas eliminaciones de assets legacy. `netlify.toml` usa `npm run build` y publica `dist` con Node 22.

## Límites de certificación antes del deploy
La auditoría estática y de backend no sustituye las últimas pruebas manuales de usuario real. Siguen siendo puertas de QA, no fallos conocidos:
- publicar foto/vídeo real en Combat Social y verificar renderizado;
- crear un comentario real desde otra identidad y abrir su perfil desde el comentario;
- publicar una ficha real de Showcase con imagen;
- cambiar entre los cuatro temas desde Configuración y revisar visualmente PC/móvil;
- probar código de alumnos/familias y código de equipo con cuentas de prueba;
- recorrer el Manual interactivo en móvil y PC.

## Veredicto
**Candidato 20037 preparado para última validación local y, tras autorización explícita, commit/deploy. No se conocen fallos bloqueantes tras la auditoría, pero no se afirma ausencia absoluta de bugs sin las pruebas manuales anteriores.**
