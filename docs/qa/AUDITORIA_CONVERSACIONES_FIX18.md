# FIX18 acumulativo: conversaciones por identidad y Competidor piloto

## Cambios implementados
- Competidor, Profesional, Marca y Federación incorporan Conversaciones con los cuatro canales existentes de Club: Social, Showcase, Assist y Migrations. No se sustituye el sistema de Club.
- La bandeja se filtra por identidad en el servidor antes del límite de resultados. La interfaz también filtra participantes y canal. El cambio de canal relee permisos; una revocación no selecciona otra identidad de la cuenta como alternativa.
- Assist usa la identidad autorizada del servidor. Migrations de Competidor/Profesional prepara documentación; no genera alumnos, cargos ni pagos. La importación real sigue limitada a Club y a su confirmación existente.
- Leer Social no requiere suscripción si la cuenta dispone de un perfil público accesible. Publicación, mensajes, minoría de edad, venta y cobros mantienen sus controles independientes.
- Los siguientes cinco perfiles Competidor elegibles, pertenecientes a cuentas distintas, reciben autorización automática de piloto. Registro privado de la causa: autorización Owner sin revisión documental. No caduca al completarse las plazas. No se han validado documentos ni concedido suscripciones comerciales.
- Asignación atómica mediante bloqueo de la fila de cupo; máximo cinco concesiones. Las altas fallidas se revierten con la transacción. No se reasignan automáticamente plazas al eliminar un perfil.
- Se exige una fecha de nacimiento ya presente en la cuenta y edad mínima de 16 años. Descubrir y las funciones de adultos conservan su control de 18+. La aceptación de normas Social sigue siendo explícita. Las cuentas sin edad registrada siguen el flujo ordinario.
- El editor ya existente de Competidor contiene disponibilidad, varias disciplinas, categoría, peso, historial declarado, territorio y fechas opcionales. Se comprobó su presentación y guardado. Descubrir exige perfil activo/verificado, adulto y visibilidad configurada; no se inventa disponibilidad.

## Verificado en Supabase
Aplicadas las migraciones registradas 20261007071657, 20261007072152, 20261007073208 y 20261007073429. Función kombax-assist-r38 actualizada a versión 16, conservando verify_jwt=true y comprobación propia de usuario.

Pruebas reales SQL con rollback:
- Cuatro tipos: propietario autorizado, contexto exacto, Migrations autorizado, cuenta ajena rechazada sin fallback y editor activo/revocado.
- Seis cuentas de prueba mediante app_kombax_perfil_mutate_r58: primeras cinco habilitadas; sexta ordinaria. Espacio de cada identidad correcto y todas las capacidades base Competidor presentes.
- Acceso al RPC de conversaciones sin suscripción tras el alta piloto.
- Al finalizar no quedaron cuentas de prueba ni concesiones consumidas: cinco plazas disponibles en la comprobación de cierre.
Estas pruebas no equivalen a una prueba HTTP completa con sesiones reales ni a una carrera concurrente de altas.

## Pruebas aisladas
- Edge: 38 verificaciones con proveedor IA simulado; sin inferencias reales ni gasto IA. Preservación de autenticación, créditos, contexto servidor, extracción Club y rechazo de registros Club para documentos personales.
- Edge anterior FIX16: 29 comprobaciones conservadas.
- Navegador Edge aislado móvil y escritorio: 30 comprobaciones en cada tamaño. Cuatro canales, cambio de canal, separación de bandejas/contexto y revocación. Transportes de repositorio simulados; no se enviaron mensajes.
- Competidor: 11 comprobaciones de información pública y formulario real de disponibilidad; guardado simulado conserva dos disciplinas y selecciona el perfil correcto.
- Regresión de imágenes FIX17: 20 comprobaciones aisladas.
- Regresión: acceso a espacios FIX14 (13), catálogo autorizado IA FIX16 (10), familias/múltiples hijos R120 (25), operaciones de perfiles R120 (29), identidad gratuita R112 (12) y visibilidad gratuita R112 (10).
- Una suite estática R60 falla la aserción literal de nombre de ruta, anterior a la traducción. Reproducido extrayendo FIX17 y ejecutando la misma suite. No se alteró el test ni la línea base; evidencia QA_BASELINE_CONVERSACIONES_FIX18.json. No se ejecutó toda la batería histórica.
- Compilación y compatibilidad Linux: 643 recursos, 377 JavaScript, 909 importaciones; web=dist=recursos Android. No APK/AAB compiladas.

## Límites y actualización
Las reglas backend ya están aplicadas. Hay que desplegar el frontend de este ZIP en Netlify para mostrar la navegación y los avisos nuevos. No se hizo push, despliegue web ni publicación Play. Una aplicación con recursos empaquetados requiere recompilación; versionCode 20178 ya se utilizó en Google Play.

Los créditos IA existentes no se han ampliado; el canal no concede consumo ilimitado ni importación de datos de Club desde otras identidades. La disponibilidad de venta exige la verificación y el servicio comercial correspondiente.

Advisors consultados tras DDL: persisten avisos sobre RPC security-definer, tablas privadas con RLS sin políticas y protección de contraseñas filtradas desactivada. Las dos tablas nuevas de cupo están en esquema privado sin acceso de anon/authenticated y con RLS; la ausencia de políticas permite únicamente la operación interna autorizada. Esto no es una auditoría exhaustiva de seguridad. Referencias: https://supabase.com/docs/guides/database/database-linter y https://supabase.com/docs/guides/auth/password-security.

Entrega acumulativa, conserva documentación y migraciones anteriores. FIX17 original intacto. Cuatro fragmentos binarios de un ZIP, reunificador CMD, manifiesto SHA-256 y validación CRC de todas las entradas.
