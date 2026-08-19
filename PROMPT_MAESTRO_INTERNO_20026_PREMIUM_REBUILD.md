# PROMPT MAESTRO INTERNO · KOMBAX PREMIUM REBUILD · RC13 BUILD 20026

## Misión
Reconstruir la capa visual y de interacción de KOMBAX/Urban Warriors a partir del build 20025 FINAL verificado, manteniendo intacta la arquitectura funcional, los contratos de backend, el aislamiento multitenant, la compatibilidad Android y la ruta de firma existente. El resultado debe sentirse como un SaaS premium real de 2026 en móvil y escritorio, no como una demo decorada.

## Fuente de verdad
- Base inmutable: `KOMBAX_Urban_Warriors_RC13_build_20025_FINAL.zip`.
- SHA-256 base: `93bb8c6637d15ca1d5abe1db7829d82edf9b629ad45cf82be2ced6360475c9eb`.
- `applicationId`: `com.urbanwarriors.app`.
- Siguiente `versionCode`: `20026`.
- Urban Warriors sigue siendo el tenant real inicial.
- No ejecutar SQL ni tocar Supabase remoto.
- No desplegar Netlify.
- No incluir JKS, claves, secretos, APK ni AAB.

## Estándar estético obligatorio
1. Negro dominante: fondo profundo casi negro con superficies grafito.
2. Rojo KOMBAX visible y estructural, no decorativo: iluminación ambiental, trazas, estados activos, foco, indicadores y llamadas a la acción.
3. Blanco frío para contraste y jerarquía; el rojo no debe invadir el contenido.
4. Lenguaje visual “combat-tech editorial”: preciso, atlético, sobrio, premium; prohibido aspecto videojuego, casino, neón excesivo o glassmorphism gratuito.
5. Profundidad por capas, bordes, luz direccional y composición; no por sombras pesadas.
6. En móvil, densidad alta pero respirable; tarjetas compactas, targets táctiles de 44–48 px y bottom navigation estable.
7. En escritorio, aprovechar anchura y jerarquía; nunca ampliar una pantalla móvil.
8. KOMBAX domina puerta, perfiles globales, Social y Showcase. Dentro del club, el club domina y KOMBAX firma como plataforma secundaria.

## Iconografía
- Crear una familia SVG propia y coherente en código, sin emojis ni abreviaturas visuales.
- Navegación operativa: trazo consistente, lectura inmediata a 20/24/28 px.
- Accesos globales y perfiles: iconos “hero” más ricos, con geometría multicapa y acento rojo controlado.
- No usar raster generado por IA como control.
- Prohibidos `01/02`, `CO/MA/FE/ES/PR` y similares como iconos.

## Interacción y movimiento
- Transiciones de vista 180–240 ms con `opacity + translate` y easing suave.
- `pressed` inmediato en móvil; hover y focus visibles en escritorio.
- Sidebar móvil con scrim y desplazamiento táctil.
- Bottom navigation fija con estado activo inequívoco y safe area.
- Modales/bottom sheets sin pérdida de foco y respetando `prefers-reduced-motion`.
- Ninguna animación continua decorativa.

## Puerta KOMBAX
- Símbolo KOMBAX exacto disponible en assets; no redibujarlo.
- Wordmark puede componerse tipográficamente como texto si no existe master exacto; no fingir un SVG oficial inexistente.
- Fondo negro con campos de luz roja, líneas técnicas discretas y patrón estructural.
- Dos accesos: `Entrar con mi club` y `Crear o acceder a un perfil KOMBAX`.
- Cada acceso usa iconografía hero propia, descripción corta y flecha.
- Cierre: `CONNECT · COMPETE · GROW`.

## Directorio
- Búsqueda premium compacta, filtro visual, feedback de carga/error/vacío.
- Urban Warriors destacado como club real.
- DEMO inequívoco en clubs ficticios.
- Monograma solo cuando no hay logo.
- Fila completa clicable; sin emblemas inventados.

## Login
- Urban Warriors protagonista; KOMBAX firma secundaria.
- Visual editorial en desktop y formulario único en móvil.
- Inputs con icono, labels, foco rojo/white de alto contraste.
- Mostrar/ocultar contraseña.
- Crear cuenta, invitación, instalar app y volver a elegir club preservados.
- No cambiar autenticación ni contratos.

## Shell privado
- Mantener arquitectura y recorridos del 20020/20021 acumulados en la base.
- Rediseñar visualmente sidebar/topbar/bottom-nav sin cambiar IDs, rutas ni permisos.
- Navegación agrupada, compacta y profesional.
- Active state: rojo KOMBAX como señal, nunca gran bloque rojo.
- Dashboard, cards, tablas, formularios, recibos, comunidad y contenido deben compartir tokens.

## Seguridad funcional
- Showcase sigue siendo escaparate: sin carrito, checkout, pagos ni logística.
- Social: sin seguidores ni chat completo.
- Perfiles futuros cerrados por feature flags y capacidades.
- Espectador no público.
- No cambiar edades, privacidad, permisos o modelo comercial.

## Calidad técnica
- CSS/JS/SVG locales, sin dependencias visuales externas.
- Mantener HTML semántico y módulos ES.
- No introducir lecturas/mutaciones directas fuera de repositorios/gateway.
- Mantener service worker sin cachear runtime JS/CSS/HTML.
- Actualizar `web`, `dist` y Android mediante build reproducible.
- PWA y launcher deben presentarse como KOMBAX; el interior del tenant sigue siendo Urban Warriors.

## QA obligatorio
- Ejecutar suite completa heredada.
- Añadir pruebas 20026 para: build, identidad Android, iconos KOMBAX, ausencia de placeholders, ausencia de Impact, manifest KOMBAX, versionado, motion reducido, safe areas, rutas/feature flags, Social sin chat/seguidores y Showcase sin comercio.
- Ejecutar build reproducible y comprobar `web = dist = Android`.
- Ejecutar preflight Android; aceptar como pendientes únicamente secretos/configuración local no incluidos por diseño.
- Si Chromium local permite render, capturar puerta a 390x844, 412x915 y 1440x900 y revisar overflow.
- No declarar validación física Android/iPhone ni Supabase remoto si no se ha realizado.

## Regla final
No cerrar por “se ve bonito”. Cerrar solo si la interfaz demuestra jerarquía, coherencia, densidad, iconografía propia, continuidad responsive, interacción, accesibilidad, build reproducible y regresión funcional en verde.
