# KOMBAX / Urban Warriors · RC13 build 20026 · Premium Rebuild Report

## Resultado
Este build se ha reconstruido desde el ZIP 20025 FINAL verificado, no desde la propuesta 20026 V2 rechazada. El objetivo ha sido elevar la capa visual, la iconografía y la interacción sin reescribir el dominio funcional ni tocar el Supabase remoto.

## Base verificada
- Fuente: `KOMBAX_Urban_Warriors_RC13_build_20025_FINAL.zip`
- SHA-256: `93bb8c6637d15ca1d5abe1db7829d82edf9b629ad45cf82be2ced6360475c9eb`
- `applicationId`: `com.urbanwarriors.app` (sin cambios)
- `versionCode`: `20026`
- PWA / launcher: `KOMBAX`
- Urban Warriors: tenant real inicial y protagonista dentro de su entorno privado.

## Qué se ha reconstruido
### 1. Foundation visual
- Nueva capa `web/css/kombax-premium.css` sobre la arquitectura existente.
- Negro dominante, rojo KOMBAX estructural y blanco frío de alto contraste.
- Fondos con campos de luz roja, geometría diagonal y trazas técnicas, sin estética de videojuego/neón.
- Jerarquía editorial específica para móvil y escritorio.
- Safe areas, targets táctiles, foco visible y `prefers-reduced-motion`.
- `Impact` eliminado como identidad principal.

### 2. Puerta KOMBAX
- Composición editorial completamente nueva.
- Dos accesos claros: club e identidad KOMBAX.
- Iconografía protagonista SVG de 64×64 propia.
- Fondo negro con estructura roja visible pero subordinada al contenido.
- `CONNECT · COMPETE · GROW` conservado.

### 3. Directorio multiclub
- Buscador, filtros, estados de carga/error/vacío y tarjetas más densas.
- Urban Warriors real diferenciado de clubes DEMO.
- Toda la tarjeta es accionable.
- No se inventan escudos para clubs demo.

### 4. Perfiles KOMBAX
- Eliminados los placeholders visuales `CO/MA/FE/ES/PR`.
- SVG propios para Competidor, Marca, Federación, Espectador y Profesional / Representante.
- Estados futuros siguen cerrados y se comunican como `PRÓXIMAMENTE`.
- Espectador continúa no público.

### 5. Login del club
- Urban Warriors continúa como identidad principal del tenant.
- KOMBAX se presenta como firma de plataforma.
- Campos con iconografía, foco consistente y mostrar/ocultar contraseña.
- Se conservan login, registro, invitación, instalación y cambio de club.
- La llamada de autenticación sigue siendo la existente (`backend.signIn`).

### 6. Shell privado
- Se conserva la arquitectura funcional acumulada de la base.
- Sidebar, topbar, cards, tablas, formularios y bottom navigation reciben la nueva foundation.
- Bottom navigation móvil más compacta y con estado activo inequívoco en rojo.
- Transiciones de vista de 180–240 ms y feedback táctil/hover/focus.

### 7. Identidad instalable
- PWA renombrada a KOMBAX.
- Android `android:label="KOMBAX"`.
- Iconos PWA/maskable y launcher Android regenerados desde el símbolo KOMBAX existente, mediante composición determinista; no se redibujó el símbolo con IA.
- Splash/foreground Android sincronizados.

## Integridad funcional / backend
- `web/js/core/backend.js`: idéntico al 20025.
- `web/js/core/repositories.js`: idéntico al 20025.
- Carpeta `supabase/`: idéntica byte a byte frente a la base 20025 en la comparación de árbol.
- No se ha ejecutado SQL.
- No se ha tocado Supabase remoto.
- No se ha desplegado Netlify.
- No se han incluido JKS, claves privadas, `.env`, APK ni AAB.
- Migraciones 037–042, verificaciones y rollbacks heredados permanecen empaquetados.

## QA ejecutado
- Suite heredada + prueba específica premium 20026: **PASS**.
- Total de scripts de prueba encadenados: **36**.
- `npm run build`: **PASS**.
- Build reproducible: **64 archivos web = dist = Android assets**.
- Sintaxis de módulos modificados: validada durante la fase de implementación.
- Prueba 20026 comprueba versionado, applicationId, PWA KOMBAX, CSS premium, iconos propios, ausencia de Impact/placeholders, perfiles futuros cerrados, assets y migraciones empaquetadas.

## Android preflight
Resultado actual: **3/5**.

OK:
1. `applicationId com.urbanwarriors.app`.
2. `versionCode 20026`.
3. `android/app/src/main/assets/www` sincronizado.

Pendiente por diseño local:
1. `android/app/google-services.json` real.
2. `android/keystore.properties` apuntando al JKS existente.

Estos dos elementos no se incluyen en el ZIP por seguridad.

## Validación visual automatizada
Se intentó levantar el servidor local correctamente en `127.0.0.1:4173`. El Chromium headless disponible en este entorno no llegó a producir capturas y quedó bloqueado por limitaciones del runtime, por lo que **no se declara como realizada la revisión visual física de viewport**. La validación en navegador real, Android Studio/device y PWA queda para el entorno local del usuario.

## Pendiente antes de declarar release
1. Abrir localmente y revisar 390×844 / 412×915 / escritorio.
2. Conectar con el Supabase autorizado y verificar compatibilidad real antes de aplicar migraciones remotas.
3. Añadir `google-services.json`.
4. Configurar el JKS existente mediante `keystore.properties`.
5. Repetir `npm run android:preflight` hasta 5/5.
6. Generar release APK/AAB localmente y probar actualización sobre la app instalada.
7. Probar push en dispositivo físico.
8. Solo después, decidir despliegue PWA/Netlify.

## Veredicto
**CANDIDATA PREMIUM 20026 PREPARADA PARA VALIDACIÓN LOCAL Y ANDROID.** La regresión está en verde y el build está sincronizado. No se certifica todavía la apariencia física en dispositivos ni la conectividad/migración de Supabase remoto.
