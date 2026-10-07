# FIX19 acumulativo · acceso gratuito y validación para publicar

Revisión del 7 de octubre de 2026. Incluye las revisiones anteriores, conservando FIX18 intacto. Esta versión sustituye el informe preliminar de acceso de FIX19.

## Cambios de producto

Una cuenta gratuita mantiene la lectura de Social, Showcase y Events y la elegibilidad de compra sin crear automáticamente un perfil público. Social y el espacio general invitan voluntariamente a «Crear o gestionar mi perfil» mediante el selector existente, conservando las condiciones y controles de seguridad. Las organizaciones con perfil público ya creado no se identifican erróneamente como cuentas sin perfil.

Espectador puede comentar, dar «me gusta» y guardar, pero no publicar. El compositor requiere permiso de publicación explícito del servidor; un permiso ausente no se interpreta como autorización. Miembro necesita vinculación aprobada a un club; los demás tipos conservan su verificación correspondiente.

## Backend aplicado y pruebas reales

Migraciones aplicadas al proyecto Supabase poggsobhtutbuagjiydc:

- 20261007100452: la comprobación antigua de acceso Social delega en la lectura gratuita existente, sin añadir otro circuito.
- 20261007100709: corrección del conflicto de índice parcial al guardar solicitudes comerciales puntuales. No activa ventas ni ejecuta cobros.
- 20261007101702: Club necesita un alta verificada o una autorización piloto activa, además de los permisos existentes del equipo, para publicar.

Se ejecutaron los tres SQL de supabase/tests terminados en fix19 con rol authenticated y reversión de cada transacción. Resultado en QA_REGLAS_ACCESO_FIX19.json:

- Cuenta adulta sin perfil: feed, directorio, Showcase, Events y elegibilidad de compra accesibles. No se efectuó una compra.
- Espectador creado mediante el registro real: comentar, guardar y dar like permitidos; publicación rechazada por el servidor.
- Marca, Federación, Profesional y Media sin verificar: publicación rechazada.
- Competidor autorizado piloto: publicación permitida tras aceptar normas; sin validación, publicación y organización rechazadas.
- Miembro público sin vínculo aprobado: publicación rechazada.
- Competidor sin suscripción Club: borrador de evento y solicitudes puntuales de publicación y Ticketing guardadas. Son solicitudes, no activaciones ni pagos.
- Club piloto autorizado conserva publicación; el mismo club sin alta verificada ni autorización piloto no publica. Los otros dos clubes piloto conservan permiso. Un Club con alta verificada puede publicar sin depender de la excepción piloto.

Las transacciones se revirtieron: cero usuarios QA restantes, cero plazas Competidor consumidas y tres clubes piloto activos al cierre. No se enviaron correos ni se llamó a Stripe en estas pruebas.

## Navegador aislado y regresión

Edge con repositorios simulados, sin autenticación real de producción: 22 comprobaciones a 390 px y 22 a 1440 px, sin errores JavaScript. La invitación abre el selector existente sin escribir perfiles; conserva las entradas Social, Showcase y Events. Espectador no muestra compositor incluso ante una respuesta simulada incorrecta que le conceda permiso. Competidor requiere permiso explícito. Capturas revisadas visualmente: PERFIL_GRATUITO_FIX19_390.png y PERFIL_GRATUITO_FIX19_1440.png.

Regresión enfocada: conversaciones FIX18 (30), familias y matrículas R120 (25), operaciones de perfiles R120 (29), acceso a espacios FIX14 (13), identidad gratuita R112 (12) y visibilidad R112 (10), superadas. La prueba antigua de conversaciones R60 se actualizó para comprobar las rutas actuales y sus etiquetas desde las traducciones, en vez de exigir texto literal antiguo en app.js; conserva sus 28 condiciones y todas pasan.

Se añadieron traducciones de respaldo en inglés de los textos nuevos y 23 frases recientes sin cobertura. Los idiomas no españoles conservan la política de respaldo existente; no se afirma una traducción nativa completa. No se modificó la lista de incidencias heredadas de traducción para admitir fallos nuevos.

## Compilación, límites y actualización

Consultar BUILD_FIX19.log y COMPROBACION_NETLIFY_20178_FIX19.txt para el resultado final del control de entrega. No se ha realizado un despliegue frontend ni publicación en Google Play. Las pruebas aisladas no equivalen a una prueba integral con usuarios reales en producción, compras Stripe o APK.

Las reglas backend ya están aplicadas al proyecto indicado. Para mostrar las nuevas invitaciones y controles visuales se debe desplegar este frontend en Netlify. No reaplicar manualmente estas migraciones al mismo proyecto. Para una app con recursos embebidos se requiere reconstruirla; no se incluye APK/AAB compilada. El código Android 20178 ya usado debe sustituirse por otro no utilizado al generar la próxima AAB.

Se conservan el catálogo vigente, la contratación pública nueva de Marca/Federación bloqueada, las finanzas autorizadas y las automatizaciones de cobro desactivadas. No se han cambiado imágenes ni assets en esta revisión.

Se consultaron los avisos de Supabase: persisten advertencias del proyecto sobre funciones security definer y protección frente a contraseñas filtradas. Esta revisión no es una auditoría exhaustiva de seguridad. Referencia: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

Resultado final: npm run build terminó con código 0. Control piloto Netlify: 108 PASS, tres P2 heredados de traducción registrados por la lista exacta existente, cero fallos nuevos. Compatibilidad: 377 archivos JavaScript, 910 importaciones locales válidas para Linux, build 20178, web/dist/Android idénticos. La suite estricta npm test conserva los fallos heredados de traducción; no se presenta como completamente superada.
