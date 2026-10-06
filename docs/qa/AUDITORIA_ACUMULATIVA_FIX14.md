# Auditoría acumulativa FIX14

Fecha: 6 de octubre de 2026. Base acumulativa: FIX13 / build 20178. No hubo push, despliegue Netlify ni publicación Google Play.

## Cambios comprobables

- Destino de acceso elegido sin declarar cuántos perfiles existen. Cero identidades lleva a exploración, una permite entrada directa y varias permiten seleccionar. La administración de cuenta se abre explícitamente. Se conservan condiciones, verificación y pasos de seguridad.
- Menú lateral común y persistente por identidad, colores LED de Club, selector de identidad y cierre de sesión. El menú de cuenta no se superpone al de identidad. Las herramientas conservan la entidad seleccionada.
- Logo/foto y banner administrativo en almacenamiento privado, con imágenes públicas como presentación inicial. Permisos de lectura/edición por identidad; archivo y eliminación reservados al propietario.
- Paneles Marca/Federación/Profesional consultan los repositorios de actividad existentes. Un dato ausente aparece como «—» y un error genera aviso; no se presenta como cero real. El resto conserva herramientas y contexto de su actividad.
- Búsqueda por nombre/tipo y vista de archivados, recuperación, solicitud individual de eliminación y cancelación en estados permitidos. El archivo administrativo no cambia publicaciones ni suscripciones.
- Entrada al trámite de vendedor para la entidad elegida; borrador previo a verificación. El permiso delegado sobre un proveedor se revalida y desaparece al revocar el acceso. No equivale a habilitar Commerce ni cobrar.
- Grados independientes por disciplina, nivel y color; edición conservando la disciplina. La base de datos impide trasladar un grado utilizado a otra disciplina y rechaza niveles/colores inválidos.
- Cambio de rol de un miembro existente por el titular: sustituye sus funciones operativas, preserva otros miembros, registra historial y revoca invitaciones pendientes anteriores del mismo destinatario. La titularidad no se modifica. Varias personas pueden compartir rol.
- Coordinación puede operar alumnos/matrículas/pagos manuales; no puede aprobar accesos del equipo, cambiar roles, solicitar cambio de plan, abrir el portal de suscripción del club ni solicitar su eliminación. Administración titular conserva esas decisiones. Aplica también en piloto.

## Pruebas aisladas

| Suite | Comprobaciones | Alcance |
|---|---:|---|
| `test-workspace-access-fix14.mjs` | 13 | Destino cuenta/directo, cero/una/varias identidades, archivo, suspensión y guardas |
| `test-workspace-private-fix14.mjs` | 22 | Preferencias, RLS, medios privados, propietario/editor, borrador vendedor y revocación |
| `test-club-repeated-roles-fix14.mjs` | 12 | Cuatro coordinadores y varios secretarios, aprobación por titular, conservación de otros miembros |
| `test-profile-repeated-roles-fix14.mjs` | 34 | Invitaciones y roles repetidos Marca/Federación/Profesional/Media |
| `test-club-grades-role-change-fix14.mjs` | 24 | Grados, sustitución de roles, auditoría, decisiones del titular y permiso de proveedor revocable |

Los casos SQL usan PGlite con estructuras auxiliares controladas y los cuerpos de migración entregados. No sustituyen una prueba completa de autenticación Supabase, correo o Stripe. La desactivación de una membresía en la prueba de roles repetidos es una actualización SQL aislada; no se presenta como prueba de un endpoint de revocación del club.

## Supabase real

Tres migraciones aplicadas y contrastadas con el historial del servidor:

1. `20261006091733_profile_admin_workspace_seller_entry_fix14.sql`.
2. `20261006093011_club_grade_team_role_fix14.sql`.
3. `20261006093718_club_owner_final_decisions_fix14.sql`.

Se probaron escritura/lectura de archivo administrativo, recuperación y proveedor en transacción revertida. Otra transacción creó dos grados, comprobó color/nivel, cambió temporalmente un monitor a coordinación y comprobó que coordinación no pudiera cambiar roles ni contratar. Una tercera comprobó el rechazo de eliminación del club por un no titular. Se estableció la identidad de sesión desde SQL para esas pruebas; no se usaron contraseñas ni se afirmó una sesión real de navegador.

Lectura posterior: cero grados QA restantes y cero cambios de rol persistidos por las pruebas; RLS del historial activa; RPC de rol no ejecutable por `anon`; bucket administrativo privado y RPC de preferencias/vendedor no ejecutables por `anon`.

Configuración leída: cuatro clubes activos con panel manual habilitado. Ambos clubes registrados en el registro piloto conservan informes Premium. Cuatro clubes tienen informes habilitados en su configuración. Los flags recurrente/cobro piloto configurados están desactivados (cero activos). Cero planes nuevos Marca/Federación con contratación pública publicada. No se ocuparon plazas nuevas.

El asesor de seguridad enumera seis RPC/helper FIX14 autenticados como `SECURITY DEFINER`. Es exposición intencional para operaciones autorizadas/RLS, no acceso anónimo: se revisaron autenticación, permisos por entidad, `search_path` y grants. El aviso se conserva; no se afirma un proyecto sin avisos históricos. [Descripción oficial del control](https://supabase.com/docs/guides/database/database-linter).

## Navegador

Chrome con transportes/repositorios simulados, sin editar cuentas reales:

- **40 comprobaciones FIX14:** opciones del login y ausencia de pregunta general en alta piloto; búsqueda y archivo/recuperación; una barra por identidad y persistencia en herramientas; datos y estados de error; eliminación de una sola identidad; dos marcas y tienda elegida; vendedor no verificado guarda borrador; grado con disciplina/nivel/color; cambio de rol sobre el mismo miembro; coordinación sin acciones definitivas; ancho móvil.
- **42 comprobaciones acumulativas:** ficha administrativa con grupos/disciplinas adicionales, tutor seleccionando otro hijo sin confundir sus matrículas, importes en unidades menores para la identidad correcta, escritura financiera según servicio y tarjetas LED de Marca/Federación/Profesional/Media.
- Capturas móvil y escritorio inspeccionadas: logo/banner de muestra, presentación, métricas y menú LED. Son muestras de prueba, no estadísticas de producción.

Evidencia: `QA_NAVEGACION_FORMULARIOS_FIX14.json`, `QA_CONTEXTO_FAMILIAS_FIX14.json` y capturas en esta carpeta.

## Regresión y compilación

Resultado final: 96 suites aprobadas, tres P2 heredados y cero fallos nuevos; 639 archivos sincronizados entre web, dist y Android, y 895 importaciones locales comprobadas para Linux. Los controles R74/R75 se adaptaron a los parámetros de identidad seleccionada conservando sus comprobaciones de separación pública/privada.

El resultado final se adjunta en `COMPROBACION_NETLIFY_FIX14.txt`. La puerta de entrega ejecuta las cinco suites FIX14 más la regresión acumulativa, compila web/dist/recursos Android y valida compatibilidad de importaciones/rutas. No se modificó la lista de traducciones heredadas para aceptar errores nuevos.

Los tres bloqueos históricos P2 siguen siendo los auditores de traducción estricta y la comprobación R79 relacionada. El respaldo inglés nuevo no representa traducciones nativas completas a ocho idiomas. `npm test` estricto continúa señalando esa deuda.

## Límites y actualización

No se probó una compra/cobro real, correo real, subida Storage desde una cuenta de producción ni una APK en dispositivo. La compilación/sincronización web no equivale a construir una AAB. Netlify y la app instalada necesitan recibir los recursos nuevos para mostrar los formularios y navegación actualizados; las restricciones aplicadas en Supabase ya protegen las operaciones del servidor.

Consultar `LEEME_KOMBAX_20178_FIX14.md` para reunificación y actualización. Se preserva FIX13 y se verifica el nuevo ZIP con CRC, SHA-256 y ejecución del reunificador.
