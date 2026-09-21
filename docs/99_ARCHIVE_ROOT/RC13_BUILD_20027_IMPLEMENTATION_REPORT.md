# KOMBAX / Urban Warriors · Informe de implementación y QA

## Release

- Fecha: 2026-08-17
- Baseline obligatorio: `KOMBAX_Urban_Warriors_RC13_build_20026_PREMIUM_REBUILD_FINAL.zip`
- SHA-256 baseline: `c92544802c9eb42ec0d3697c722cc3260bb671558fe10cf14c4d929cb1417e28`
- Build de trabajo/entrega: **20027**
- Android `applicationId`: `com.urbanwarriors.app`
- `compileSdk`: 36
- `targetSdk`: 36
- Estado de la fuente original: no modificada; todo el trabajo se realizó sobre una copia aislada.

## Resultado ejecutivo

El build 20027 amplía el 20026 con la capa KOMBAX pendiente del Plan Maestro sin sustituir ni desmontar los módulos operativos del tenant Urban Warriors. La implementación local queda **preparada para validación**, no declarada como producción Google Play lista.

Se han completado en código los ciclos 043–050, la interfaz y repositorios asociados, la página pública operativa de solicitud de eliminación y pruebas de regresión. No se han aplicado migraciones al Supabase remoto ni se ha generado una release Android firmada porque esos pasos requieren recursos externos reales (proyecto Supabase, `google-services.json`, JKS/`keystore.properties`, Gradle/Android Studio y Play Console).

## Implementado

### 1. Identidad global KOMBAX y perfiles

- Cuenta global KOMBAX separada del acceso de club.
- Creación/edición de perfiles directos: Competidor, Marca, Federación y Profesional/Representante.
- Solicitud de Club como proceso de revisión; no crea un tenant automáticamente.
- Espectador se mantiene cerrado/limitado.
- Estados de verificación: `draft`, `submitted`, `under_review`, `needs_information`, `verified`, `limited`, `suspended`, `rejected`.
- Documentación de verificación privada y separada del contenido público.
- Insignia/capacidades dependientes del estado verificado; registrarse no equivale a estar verificado.

### 2. Álbum multimedia

- Perfiles KOMBAX: avatar y banner separados del álbum.
- Hasta 10 fotografías y 3 vídeos simultáneos.
- Vídeos limitados a 15 segundos.
- Estados de contenido y moderación.
- Validación de MIME, tamaño/resolución y nombres de objeto controlados por backend.
- Storage diferenciado entre multimedia pública y documentación privada.
- Álbum del Club implementado con los mismos límites principales.

### 3. KOMBAX Social

- Hasta 30 publicaciones activas por perfil habilitado.
- Máximo 3 publicaciones nuevas al día.
- Máximo 10 publicaciones activas con vídeo; vídeo máximo 15 s.
- Like reversible, guardado privado, compartir enlace.
- Comentarios y una única capa de respuesta.
- Modos de comentario: abiertos, verificados o cerrados.
- Denuncia de publicación, comentario y perfil.
- Bloqueo de perfil.
- Cola de moderación y acciones auditadas.
- Social global conectado al hub KOMBAX, no como pantalla decorativa aislada.

### 4. Regla de edad y menores

Se ha cerrado expresamente una vía que podía permitir que un perfil personal global activase Social solo por estar verificado por KOMBAX. En 20027:

- Competidor/Profesional directos pueden existir y pasar verificación de identidad/profesión.
- Su activación directa de KOMBAX Social queda bloqueada hasta disponer de **edad verificada por club**.
- La identidad afiliada al club conserva el flujo Social con regla 14+ verificada por club.
- Marca/Federación no dependen de una fecha de nacimiento personal para la activación social institucional.
- No se habilita contacto privado del Espectador.

Esto aplica una política conservadora: no se utiliza la verificación de identidad como sustituto de la verificación de edad.

### 5. Contactos y relaciones verificadas

- Solicitud de contacto estructurada en lugar de chat libre entre desconocidos.
- Motivos permitidos según la relación entre tipos de perfil.
- Aceptar / rechazar / bloquear / denunciar.
- Relaciones verificadas en lugar de seguidores: Competidor↔Club, Club↔Federación, Competidor↔Profesional, Marca↔Club/Competidor, etc.
- Relaciones sensibles requieren confirmación/autorización; no se publican unilateralmente.

### 6. Showcase

- Club: máximo 15 fichas visibles.
- Marca: máximo 30 fichas visibles.
- Imagen principal + hasta 3 imágenes adicionales.
- Categoría, descripción, precio orientativo opcional, web/contacto y localización/dónde encontrar.
- Estados publicado/archivado/suspendido.
- Marca global verificada puede gestionar su Showcase sin pertenencia artificial a un Club.
- Se mantiene fuera: carrito, checkout, pagos KOMBAX, pedidos, stock transaccional, envío, devoluciones y comisiones.

### 7. Eliminación de cuenta / perfil / club

- Centro de solicitudes dentro de Ayuda/Privacidad.
- Recurso web público `delete-account.html` y ruta `/delete-account`.
- El recurso web permite autenticarse y registrar/cancelar una solicitud real; no es solo texto informativo.
- Ámbitos diferenciados: cuenta personal, perfil KOMBAX y club/tenant.
- Flujo trazable con estados, evitando `DELETE` indiscriminado de trazabilidad económica/legal.

### 8. Moderación UGC

Migración 050 y UI asociada:

- denuncia de publicación;
- denuncia de comentario;
- denuncia de perfil;
- cola de moderación para roles autorizados;
- ocultar publicación/comentario;
- limitar/suspender perfil;
- resolver/descartar denuncia con motivo;
- auditoría de acciones.

## Migraciones añadidas

- `043_kombax_profiles_verification_album.sql`
- `044_kombax_social_interactions.sql`
- `045_kombax_relations_showcase_limits.sql`
- `046_kombax_club_album.sql`
- `047_account_deletion_requests.sql`
- `048_kombax_showcase_global_mutation.sql`
- `049_kombax_social_global_access.sql`
- `050_kombax_ugc_moderation_compliance.sql`

Cada ciclo incluye archivos de preflight/verify/test transaccional/rollback según su función. No se han ejecutado contra producción desde este entorno.

## Evidencia QA local

### Suite

- `npm test`: **PASS** después del último cambio de age-gate.
- Log final: 954 líneas; final `KOMBAX BUILD 20027 IMPLEMENTATION STATIC: PASS`.
- Incluye regresión histórica RC4→RC13/KOMBAX y pruebas específicas 20027.

### Build

- `npm run build`: **PASS**.
- Resultado: `OK build 66 archivos · web = dist = Android`.
- Comparación SHA-256 independiente:
  - `web`: 66 archivos
  - `dist`: 66 archivos
  - `android/app/src/main/assets/www`: 66 archivos
  - diferencias: **0**

### SQL estático 043–050

Revisión independiente final:

- transacción de apertura: OK;
- `NOTIFY pgrst,'reload schema'`: OK;
- `COMMIT`: OK;
- delimitadores `$$`: equilibrados;
- funciones `SECURITY DEFINER` inspeccionadas: `search_path` explícito;
- incidencias estáticas detectadas: **0**.

Esto no sustituye una ejecución real en PostgreSQL/Supabase.

### Secretos

No se encontraron en el árbol de entrega:

- `*.jks` / `*.keystore`;
- `android/keystore.properties` real;
- `google-services.json` real;
- `.env` o `.env.*`.

Los ejemplos/variables de entorno permanecen como referencias, no como secretos incrustados.

## Android release-preflight

Resultado actual: **3/5**.

OK:

1. identidad `com.urbanwarriors.app`;
2. `versionCode 20027`;
3. `assets/www` presente y sincronizado.

Pendiente externo:

4. `google-services.json` real;
5. `android/keystore.properties` apuntando al JKS existente.

Por ello no se declara APK/AAB release firmado ni actualización física completada.

## Validaciones que NO se declaran realizadas

- Aplicación 043–050 al Supabase remoto.
- Verify/test transaccional sobre el proyecto real.
- RLS E2E entre dos clubes reales/QA.
- Storage real, subida/borrado y limpieza de objetos.
- Firebase/FCM real.
- Gradle Sync/assemble release en Android Studio físico.
- APK release firmada.
- AAB firmado.
- Actualización encima de 20021 en dispositivo sin desinstalar.
- Comprobación real del certificado/JKS de actualización.
- Despliegue PWA público del hash final.
- URL pública de eliminación verificada tras despliegue.
- Data Safety / App Access / Store Listing / closed test en Play Console.
- Moderación UGC E2E contra backend real.

## Limitación del entorno visual

Se intentó abrir la aplicación mediante navegador automatizado local, pero el entorno bloqueó `localhost/file` por política administrativa (`ERR_BLOCKED_BY_ADMINISTRATOR`). Esto se registra como limitación del entorno de QA, no como prueba visual aprobada. La validación visual física/navegador real sigue siendo un gate externo.

## Veredicto

**Build 20027 = candidato de release / preparado para validación.**

No debe etiquetarse como “listo para Google Play” hasta completar backend real, Android firmado/físico, URL y políticas públicas desplegadas, Data Safety/App Access, moderación E2E y el track de prueba requerido.
