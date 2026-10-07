# Activación de históricos y auditoría Competidor

Fecha: 7 de octubre de 2026. Proyecto Supabase: poggsobhtutbuagjiydc.

## Migración aplicada

`member_seniority_historical_finance_fix20`, versión real `20261007205827`. Fuente ya incluida en FIX21: `supabase/migrations/20261007195031_member_seniority_historical_finance_fix20.sql`.

Habilita fecha histórica de alta del alumno y registro manual de cargos anteriores pendientes o ya pagados. No ejecuta cobros externos. RLS activa en el registro de idempotencia; sin acceso directo anon/authenticated. RPC nueva solo authenticated y roles de finanzas autorizados.

Seis comprobaciones en la base real, dentro de transacción revertida: cargo pendiente, cargo pagado, idempotencia, pago registrado, importe negativo rechazado, antigüedad preservando fecha de creación y matrículas, usuario ajeno rechazado. Los dos estados y sus reintentos se agrupan en sendas comprobaciones. Además, 29 pruebas aisladas correctas.

## Competidor

El único competidor existente está activo y verificado, con Social activo y publicación habilitada. Continúan disponibles las cinco plazas del piloto. La prueba usa su contexto de propietario en SQL y revierte todos los cambios.

Correcto: edición del perfil verificado; avatar, banner y foto por el RPC de perfil directo; avatar, banner y foto por el RPC Social que utiliza la edición pública; creación de publicación Social. Avatar es también la imagen/logo del competidor, no un segundo logo independiente.

Storage: bucket público y MIME de imagen compatibles. Inserción de objeto de prueba permitida como rol authenticated con ruta del propietario. Ruta ajena y metadatos con ruta inválida rechazados. Son pruebas de metadatos/RLS, no una subida binaria real.

Navegador local: 11 comprobaciones de disponibilidad del competidor; 14 de preparación real de imagen y envío por repositorio con transporte simulado; 32 de interfaz Instagram con transporte simulado. No se subieron archivos a cuentas reales ni se publicaron contenidos permanentes.

## Condición pendiente de Instagram

El contexto Instagram del competidor existente devuelve `META_LEGAL_ACCEPTANCE_REQUIRED`: su cuenta debe aceptar las condiciones vigentes de la plataforma. No se han aceptado en nombre del usuario ni se ha retirado el requisito. Las comprobaciones no acreditan una conexión OAuth real, autorización externa, publicación en Instagram o eliminación de una conexión real.

Después del despliegue manual de FIX21: iniciar sesión, aceptar las condiciones vigentes, seleccionar Competidor y entrar en Social → información/ajustes → Instagram · Conexión de esta identidad. La cuenta Instagram debe ser profesional y estar vinculada a una Página de Facebook. El estado de desarrollo de Meta y sus permisos de acceso siguen condicionando las cuentas autorizables. No se ha publicado contenido real en Instagram.

## Advisors y entrega

Rendimiento: 256 avisos de claves foráneas sin índice, 305 índices sin uso y 1 duplicado; sin incremento frente a la revisión anterior. Seguridad: 235 tablas con RLS sin políticas, 60 funciones definer accesibles a anon, 640 a authenticated y aviso previo de protección de contraseñas filtradas. Los incrementos de una tabla privada cerrada y una RPC autenticada corresponden a esta migración; no se abrieron políticas públicas para silenciar avisos. Son avisos agregados que requieren revisión propia, no una garantía de ausencia de vulnerabilidades.

No se ha modificado frontend ni ZIP FIX21. No se ha repetido el build completo de frontend: esta intervención es exclusivamente Supabase y pruebas. El ZIP ya contiene la migración aplicada; su informe original queda como fotografía anterior y este documento actualiza el estado. No se hizo commit, push, merge, PR, despliegue Netlify ni compilación APK/AAB.

Evidencia estructurada: AUDITORIA_MIGRACION_COMPETIDOR_20261007.json.
