# KOMBAX 20178 · R118 FIX06 — Administración visual

Paquete acumulativo sobre FIX05. Conserva el alta piloto de cuatro clubes y el flujo de Mi Espacio. Sustituye esta guía las instrucciones anteriores de entrega; los documentos FIX01–FIX05 se conservan como historial.

## Accesos y capacidades

- Owner: entrar en la consola y abrir **Administración Social y Showcase**.
- Moderadores autorizados: desde **Social → Seguridad**, abrir Administración Social y Showcase. No concede Finanzas, verificaciones privadas ni administración de cuentas.
- Navegación visual: imágenes ampliables, vídeos reproducibles con controles y sin autoplay, productos y galerías, búsqueda, filtro de estado y páginas de 24 contenidos.
- Acciones: avisar, editar texto/nombre/resumen, retirar de Social o Showcase, restaurar tras corregir un incumplimiento, consultar historial. La eliminación de plataforma exige acceso de administración y escribir **ELIMINAR**.
- Mi Espacio: **Avisos de moderación**, con motivo y botón **Solicitar revisión**. Cada cuenta solo puede leer sus avisos; una solicitud por contenido y cuenta cada 24 horas.
- Ediciones y decisiones conservan antes/después, motivo, actor y fecha. El historial guarda únicamente campos de contenido, no costes de compra ni datos financieros internos.

## Automatización y límites reales

Hay reglas de servidor para retirar ofertas de armas de fuego, munición y explosivos expresadas con las frases españolas incluidas en la función `kombax_moderation.prohibited_offer`. Se ejecutan al crear o modificar publicaciones y productos, y generan avisos para autor y Owner. El material deportivo y las conversaciones sociales sin oferta de venta no se bloquean por estas reglas.

**No es una clasificación universal ni una IA de análisis visual:** no detecta todas las formas de contenido ilegal, otros idiomas o imágenes sin texto. La revisión visual humana cubre esos casos. No se realizó un barrido ni se moderó contenido real ya existente.

Retirar un producto deshabilita su comercio y bloquea nuevas líneas de pedido desde el servidor. El autor no puede republicar un contenido bloqueado cambiando su estado. Se conservan pedidos y recibos históricos. **No se cancelan sesiones de Stripe creadas anteriormente ni pagos ya iniciados**; requieren actuación específica del operador. No se hicieron pagos reales en QA.

Eliminar aquí es una **eliminación lógica definitiva de la plataforma**, sin restauración desde esta interfaz. Se preserva la evidencia y no se borran automáticamente archivos compartidos, álbumes ni sus URL de Storage. Retirar un post no elimina su archivo del álbum: para material ilícito alojado en Storage es necesaria una retirada del archivo y sus usos, supervisada por Owner. No se ofrece borrado físico automático por IA.

Los avisos se almacenan y pueden consultarse dentro de la aplicación. La entrega no certifica la recepción de push o email en dispositivos reales ni incluye suspensiones automáticas de cuenta.

## Supabase

Aplicadas en el proyecto actual y comprobadas:

- `20261004072423_kombax_visual_moderation_r118.sql`.
- `20261004075015_kombax_visual_moderation_notices_r118.sql`.
- `20261004080350_kombax_moderation_notice_race_r118.sql`.

No vuelvas a ejecutarlas manualmente en el proyecto ya actualizado. Para otro entorno, aplica la cadena de migraciones completa una sola vez. Las tablas de estado/historial son privadas, tienen RLS y no permiten acceso directo de anon/authenticated. Las operaciones comprueban el rol; las sesiones Owner conservan sus controles de expiración y MFA existentes. La política nueva de Storage solo permite a moderación leer archivos restringidos relacionados con publicaciones Social; no abre documentos de verificación.

Se comprobó en vivo que anon no puede consultar ni ejecutar acciones; existen los tres triggers, la política de multimedia y RLS. Se probó la inserción de avisos reales **dentro de una transacción revertida**, sin dejarlos en la bandeja. La tabla de decisiones nuevas sigue vacía: ninguna publicación o producto real fue retirado por el agente.

## QA y regresión

- 32 pruebas de Postgres aislado: permisos, avisos, edición, historial, retirada, restauración, confirmación, bloqueo de republicación/compra, pedidos preservados, reglas positivas/negativas, privacidad y revisión del autor.
- 14 comprobaciones de Chrome: vídeo generado para QA reproducido, imágenes reales del proyecto, edición, retirada, restauración, eliminación, búsqueda, historial, revisión y visualización móvil. Capturas inspeccionadas; contraste corregido.
- 18 regresiones del acceso FIX05: cuenta gratuita, identidades, Mi Espacio, clubes, equipo, códigos y alta piloto.
- Compilación local de entrega: ver `docs/qa/COMPROBACION_NETLIFY_FIX06.txt`. Tres incidencias heredadas de traducción continúan documentadas; `npm test` estricto no es completamente verde. La compilación para piloto solo admite esas incidencias concretas, no nuevos fallos.
- No se ejecutó un despliegue remoto ni una sesión real Owner de punta a punta; las pruebas de navegador usan datos simulados.

## Reunir y usar el ZIP

1. Descarga las cuatro partes `KOMBAX_20178_R118_FIX06.zip.001` a `.004` y `UNIR_KOMBAX_20178_FIX06.cmd` en la misma carpeta.
2. Ejecuta UNIR. Reúne el ZIP y comprueba su SHA-256 antes de extraer.
3. Respalda la carpeta del repositorio. Conserva **.git**, Firebase, firma y configuración privada. Copia el contenido de la carpeta extraída dentro del repositorio, evitando una carpeta contenedora adicional.
4. Usa Node 22/npm 10 y `KOMBAX_20178_VERIFY_LOCAL.cmd` para comprobarlo. No mantengas un `pnpm-lock.yaml` antiguo.
5. Revisa y realiza tú el Push origin. No se ha hecho push, despliegue Netlify ni subida a Google Play.

## Android

Los 628 archivos web se sincronizan con dist y los recursos Android. Sigue siendo build/versionCode 20178; comprueba que supera el último código subido a Play antes de generar otra AAB.

Esta revisión no produce APK/AAB ni repite la compilación nativa. En FIX05, Gradle se bloqueó por `Unable to establish loopback connection`; esa limitación permanece sin certificar. No se empaquetan claves ni archivos privados. Conserva/restaura `android/app/google-services.json`, `android/keystore.properties` y la clave original; usa Java 21/SDK 36, ejecuta `npm run android:preflight` y luego `npm run android:play:r118`. Solo los resultados de esa compilación permitirán confirmar APK/AAB.
