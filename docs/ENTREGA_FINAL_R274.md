# KOMBAX R274 · Entrega final acumulativa

Fecha: 16 de octubre de 2026.

## Resultado

ZIP completo que conserva todas las entradas de la entrega acumulativa R272 e incorpora R273/R274. No es un parche. Cuatro fragmentos binarios, reunificador CMD con comprobación SHA-256 y manifest externo de archivos añadidos/modificados.

Marca, Federación, Competidor, Profesional, Media y Espectador comparten el componente de navegación: Inicio, Perfil público, Social, Events, Showcase, Recursos y herramientas propias debajo, plegadas. Se conservan permisos y colores LED. Club conserva su navegación y permisos; la nueva propuesta de agrupación de Club permanece documentada y pendiente.

## Cambios incluidos en esta fase

- Ayuda universal con guías locales, conversación persistente entre pantallas, respuestas completas, tutorial, Enter para enviar y estado de preparación.
- Cinco consultas IA completadas por cuenta gratuita y mes; cartera existente compartida por Ayuda, Assist y Migrations para pago, sin cambiar asignaciones comerciales. Saldo mensual plegado y selección de información según identidad, rol, verificación y capa contratada.
- Menú común antes de las herramientas de negocio/deporte; grupos plegados, sin duplicar Social/Events/Showcase. Explorar Showcase abre el catálogo general; vendedor mantiene el centro de la identidad seleccionada.
- Presentación del chat más despejada y ajuste móvil. La ayuda no tapa el menú móvil mientras está abierto.

## Archivos principales

Modificados: `web/js/ui/usage-help.js`, `web/js/core/usage-help-knowledge.js`, `web/js/core/repositories.js`, `web/js/i18n/r272-usage-copy.js`, `web/css/app.css`, `web/js/ui/managed-profile-navigation.js`, `web/js/modules/managed-profile-hub.js`, `package.json`, `supabase/config.toml`, `supabase/functions/kombax-assist-r38/index.ts`, fuentes compartidas de ayuda, pruebas relacionadas y sus copias generadas web/dist/Android.

Añadidos: `supabase/functions/kombax-usage-help/index.ts`, su `deno.json`, migración de cupo gratuito, `scripts/test-help-conversation-r273.mjs`, `scripts/test-universal-help-r274.mjs`, documentación de esta fase y `LEEME_R274_DESPLIEGUE.md`. El manifest `COMPROBACION_R274.json` enumera exactamente todos los cambios respecto al ZIP base.

## Pruebas

- Pipeline final completo: **124 comandos PASS, 3 P2 heredados de traducción, cero fallos nuevos**. Registro incluido en `docs/qa/r274/RELEASE_FINAL.log`. El control legal también pasó.
- Navegación: 120/120 comprobaciones, incluidos orden de seis tipos, unicidad de accesos, restricciones y separación de Showcase público/vendedor.
- Ayuda: cuatro suites con 114 comprobaciones (27 + 46 + 9 + 32) sobre contexto, fuentes, cuota, consumo, reintentos, fallos y privacidad. Proveedor simulado; sin inferencia real facturable.
- Build: 663 archivos idénticos web/dist/Android. Linux: 395 JS y 964 importaciones locales comprobadas.
- Supabase real, con rollback: cinco consumos admitidos y sexto bloqueado; reintento en curso bloqueado; respuesta guardada reutilizada; conflicto de petición rechazado; fallo no consume cupo; club ajeno recibe ayuda genérica. Sin consumos reales persistidos por estas pruebas.
- Navegador: Competidor, Marca y Federación renderizados con componentes reales y datos de ejemplo; comprobados menú común, LED y desplegables. Revisado móvil del competidor y Federación. Esto no acredita sesiones ni operaciones de cuentas reales.

## Backend y despliegue

Migración aplicada: `universal_help_free_quota_r274`, versión remota `20261015214436`; archivo local `20261015182614_universal_help_free_quota_r274.sql`. No ejecutarla de nuevo por la diferencia de timestamp.

Funciones activas comprobadas: `kombax-usage-help` v3 y `kombax-assist-r38` v24, JWT requerido. No hay secrets nuevos que introducir. Secretos reales no incluidos en esta entrega.

Las migraciones y las cuatro funciones Meta/Instagram anteriores se conservan en el acumulativo. No se ha hecho nueva prueba real de conexión o publicación Instagram en esta fase ni se ha publicado contenido.

No se hizo push, commit, merge, PR, deploy de Netlify ni publicación Play. El usuario actualizará GitHub y desplegará el frontend siguiendo `LEEME_R274_DESPLIEGUE.md`. No se ha generado APK/AAB; solo se sincronizaron sus recursos web.

## Limitaciones documentadas

Las tres incidencias P2 de traducción siguen presentes: no se afirma que npm test estricto pase. El pipeline conserva su clasificación explícita; no se eliminaron pruebas para ocultarlas.

Los advisors conservan advertencias previas de funciones SECURITY DEFINER, protección de contraseñas y rendimiento. La tabla nueva tiene RLS y carece deliberadamente de acceso/políticas de cliente. No se declara la base libre de advertencias. Detalles: `INFORME_AYUDA_R274.md`.

Las guías son documentación de producto; el asistente no ejecuta pagos, verificaciones, publicaciones ni aprobaciones. Assist mantiene su lectura operativa autorizada. Se conserva la contratación pública nueva de Marca/Federación bloqueada y las automatizaciones financieras desactivadas.

El ZIP debe reunificarse y validarse antes de extraer. El reunificador y el SHA-256 del archivo final se entregan junto con las cuatro partes. La validación de reensamblado y CRC queda en `COMPROBACION_R274.json` después del empaquetado.
