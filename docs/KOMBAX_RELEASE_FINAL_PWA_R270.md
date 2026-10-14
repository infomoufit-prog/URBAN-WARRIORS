# KOMBAX — Entrega final acumulativa · Instalación PWA universal (R270)

Fecha: 14/10/2026. Base: ZIP fase 5C, integridad SHA-256 verificada. Incluye fases 0 a 5C y esta corrección de instalación PWA, sin reemplazar ni duplicar los módulos de backend.

## Cambios introducidos (R270)

- Controlador central `web/js/modules/pwa-install.js` (y copias idénticas en `dist/` y Android).
- Entrada **Instalar KOMBAX** en la barra lateral de **todas las identidades personales**: miembro con espacio independiente, competidor, federación, profesional, marca, media y espectador.
- Botón compacto «Instalar» visible en la cabecera móvil de esos espacios, incluso con el menú lateral cerrado.
- Conserva «Instalar app» en todos los roles de **Mi Club**, incluidos alumnos, familias y miembros de equipo; conecta el formulario antiguo con el controlador común.
- `beforeinstallprompt` gestionado una sola vez en el arranque para cualquier sesión. El prompt nativo se invoca sin `await` previo para conservar la activación del clic.
- Detección de PWA ya instalada (`display-mode: standalone` y `navigator.standalone`), wrapper Android nativo, navegadores integrados y origen HTTPS.
- Instrucciones precisas para iOS Safari, Android Chrome y escritorio si el navegador no ofrece botón de instalación directo. No se intenta instalar sin consentimiento del dispositivo.
- Cambio de marcador de cache de SW `pwa-r270` y de URL de entrada JS/CSS; se mantiene el build interno 20178 por compatibilidad con controles históricos.
- El manifiesto PWA existente (standalone, iconos estándar y maskable, scope/start_url) se conserva íntegro.

## Verificaciones locales

- 31/31 pruebas específicas de R270: PASS.
- 26/26 roles/contextos (fase 1): PASS.
- 17/17 finanzas familiares (fase 1): PASS.
- 32/32 inscripciones y licencias internas (fase 2): PASS.
- 52/52 regresión de inventario y ciclo de vida R89: PASS.
- 38/38 estabilización R118: PASS.
- 26/26 contratos y seguridad fase 5C: PASS.
- 23/23 simulaciones Meta/Instagram: PASS.
- Gate legal de publicación: PASS.
- `node scripts/sync-release-build.mjs`: PASS.
- `node scripts/build.mjs`: PASS; 654 archivos web idénticos a `dist` y `android/app/src/main/assets/www`.
- `npm run release:build` **NO CERTIFICADO** en este entorno: bloqueado en un pretest que importa `@electric-sql/pglite`, porque falta `node_modules`. No implica que ese pretest falle después de instalar dependencias. También la suite de navegador Playwright requiere su dependencia local.

## Guía de despliegue (el propietario realiza el despliegue)

1. Reconstruir las partes `.part01`–`.part04` con el CMD adjunto y comprobar el SHA-256.
2. Extraer el ZIP acumulativo; en esa carpeta debe aparecer `package.json`, `netlify.toml`, `web/`, `dist/`, `android/`.
3. En Windows, en CMD dentro de la carpeta raíz: `npm ci` y después `npm run release:build`. Requiere Node 22 e instalación de dependencias con acceso a Internet. Si el gate falla, detener el despliegue y revisar el primer error real.
4. Para publicación directa manual de la web, se incluye **otro ZIP solo de `dist/`** verificado; descomprimir y usar los contenidos de `dist` en Netlify manual deploy. Si se usa GitHub/Netlify CI, configurar root y publicar `dist` según `netlify.toml`; ese flujo ejecuta automáticamente las pruebas y puede bloquear si una suite histórica no pasa.
5. Tras publicar `https://kombax.es` (HTTPS): verificar `manifest.webmanifest`, `service-worker.js`, `assets/icons/icon-192.png`, `assets/icons/icon-512.png`, `js/modules/pwa-install.js` y `js/app.js` (200 OK). Probar instalación desde Chrome Android, Safari iOS (manual), Chrome/Edge escritorio y un espacio de cada rol.
6. Cambiar entre Mi Club, Familia, Mi Competidor, Mi Federación, Mi Profesional, Mi Marca y Media Creator sin iniciar sesión de nuevo; «Instalar KOMBAX» no debe crear otra cuenta ni alterar permisos.
7. No subir el ZIP acumulativo entero a la carpeta de publicación Netlify: solo `dist`.

## Límites antes de considerar producción completamente certificada

- Instagram: a falta de conexión OAuth real y publicación autorizada; no se ha enviado nada a Meta.
- Stripe/Events General-VIP: contratos R265/R266/R269 presentes; no se han autorizado cobros reales, reembolsos ni pruebas con tarjetas.
- Federación: vistas y módulos existentes; pruebas reales con una federación autorizada siguen pendientes.
- Google Play (publicación Android) es un canal distinto de PWA. La PWA se puede instalar desde `kombax.es` sin esperar la revisión de Google Play.
- Esta entrega no realiza push a GitHub, deploy a Netlify, ni compilación APK/AAB.
