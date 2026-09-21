# Matriz de permisos funcionales · RC13 build 20030

| Área | Dirección | Coordinación | Secretaría | Economía | Comunicación | Monitor | Alumno | Familia |
|---|---|---|---|---|---|---|---|---|
| Gestión alumnos/grupos | Sí | Sí | Sí | — | — | ámbito propio | propio | vinculados |
| Finanzas | Sí | Sí | Sí | Sí | — | — | propio | vinculados |
| Comunidad interna publicar | Sí | Sí | Sí | según reglas actuales | Sí | Sí | Sí | Sí según reglas actuales |
| Comunidad interna moderar | Sí | Sí | Sí | — | Sí | — | — | — |
| Likes | Sí | Sí | Sí | Sí | Sí | Sí | Sí | Sí |
| Perfil deportivo | moderar | moderar | según política | — | según política | lectura | propio | menor vinculado |
| Eventos/competiciones | Sí | Sí | Sí | según permiso | según permiso | según permiso | solicitar | solicitar vinculado |
| Notificaciones informativas masivas | Sí | Sí | Sí | Sí | Sí | según visibles | propias | propias |
| Notificaciones que requieren acción | revisar obligatoriamente | revisar | revisar | revisar | revisar | si aplica | si aplica | si aplica |
| Perfil público de Urban Warriors editar | **Sí** | **Sí** | No | No | No | No | No | No |
| Ver perfil público | Sí | Sí | Sí | Sí | Sí | Sí | Sí | Sí |
| Activar futura Comunidad General | No por rol equipo | No | No | No | No | No | **solo alumno elegible** | **No** |
| Denunciar/bloquear | Sí | Sí | Sí | Sí | Sí | Sí | Sí | según Comunidad interna |
| Resolver denuncias | **Sí** | **Sí** | **Sí** | No | **Sí** | No | No | No |
| Suspender acceso social | **Sí** | **Sí** | **Sí** | No | **Sí** | No | No | No |
| Diagnóstico/E2E | **Sí** | No | No | No | No | No | No | No |
| Archivo y papelera | **Sí** | **Sí** | **Sí** | No | No | No | No | No |
| Publicar/restaurar branding | **Sí** | **Sí** | No | No | No | No | No | No |

`direccion` sigue siendo el máximo nivel interno. La UI nunca sustituye las comprobaciones del backend.

## Puerta KOMBAX y contextos

| Operación | Anónimo | Miembro de club | Perfil directo | DEMO local |
|---|---|---|---|---|
| Buscar directorio público | Sí, campos públicos limitados | Sí | Sí cuando se habilite | Sí, marcado DEMO |
| Abrir acceso de un club real | Sí | Sí | — | No |
| Consultar sus propios contextos | No | Sí | Sí | No |
| Cambiar a otro club | No | Solo con membresía activa | — | No |
| Crear perfil directo | No, próximamente | No en build 20023 | No en build 20023 | No |
| Contratar/pagar | No | No en esta capa | No en build 20023 | No |

Los cinco perfiles de club adicionales son datos ficticios de desarrollo. No conceden membresía, no abren un tenant real y su fixture está prohibido en producción. Las capacidades no se deducen del aspecto de la interfaz: el backend debe resolver siempre membresía, sujeto y entitlement vigente.

## KOMBAX Social Alpha

| Operación | Deportista social elegible | Menor elegible | Equipo autorizado del club | Moderación global |
|---|---|---|---|---|
| Leer feed/directorio | Sí, con contexto habilitado | Sí, según elegibilidad existente | Sí | Sí |
| Publicar como deportista | Propio perfil activo | Sí, según edad mínima y normas | No por cuenta ajena | No por defecto |
| Publicar como club | No | No | Dirección, coordinación, secretaría o comunicación | No por defecto |
| Like | Sí, identidad privada | Sí | Sí | Sí |
| Solicitar contacto | Solo 18+ | **No** | Sí como perfil de club | Sí si actúa con perfil autorizado |
| Recibir contacto personal | Solo 18+ | **No** | — | — |
| Aceptar/rechazar solicitud | Sobre perfil propio/autorizado | **No recibe** | Sobre el perfil de club autorizado | Según perfil autorizado |
| Denunciar/bloquear | Sí | Sí | Sí | Sí |
| Resolver/ocultar globalmente | No | No | No por rol de club | **Sí, asignación explícita** |

No existe permiso para seguir perfiles, crear amistades, abrir chats, enviar respuestas encadenadas o consultar presencia. Las solicitudes de contacto son registros únicos, acotados y auditables.

## KOMBAX Showcase

| Operación | Usuario autenticado | Gestor de marca | Perfil marca verificado + entitlement | Moderación global | DEMO local |
|---|---|---|---|---|---|
| Ver catálogo publicado | Sí | Sí | Sí | Sí | Sí, marcado DEMO |
| Buscar/filtrar | Sí | Sí | Sí | Sí | Sí |
| Crear/editar ficha | No | Sí, en su marca | Sí, en su marca | Sí | No |
| Publicar/archivar ficha | No | Sí, en su marca | Sí, en su marca | Sí | No |
| Crear marca | No | No | No por sí solo | **Sí** | No |
| Publicar/verificar marca | No | No | No | **Sí** | No |
| Destacar contenido | No | No | No | **Sí** | No |
| Comprar/pagar/pedir | **No existe** | **No existe** | **No existe** | **No existe** | **No existe** |

Los enlaces externos deben ser HTTPS. Un precio, si se muestra, es únicamente orientativo. Showcase no registra operaciones de venta ni logística.
## Ámbitos de monitor · build 20030 / ciclo 057

La condición `monitor` ya no implica visibilidad global del club ni acceso a la fila administrativa completa del alumno. El alcance se obtiene de ámbitos/grupos asignados y se aplica en backend.

| Capacidad monitor | none | status | portfolio | collect | receipts |
|---|---:|---:|---:|---:|---:|
| Ver sus alumnos/grupos | Sí | Sí | Sí | Sí | Sí |
| Ver ficha administrativa completa | No | No | No | No | No |
| Ver documentos privados | No | No | No | No | No |
| Ver estado/vencimiento cuota | No | Sí | Sí | Sí | Sí |
| Ver importe/saldo | No | No | Sí | Sí | Sí |
| Registrar cobro | No | No | No | Sí | Sí |
| Referencia de recibo en cartera | No | No | No | No | Sí |

Permisos operativos independientes por monitor/ámbito: `ver_contacto`, `gestionar_asistencia`, `gestionar_seguimiento`, `responsable`. Un alumno puede estar en varios ámbitos; solo uno puede marcarse principal. Gestor/Coordinación administran las asignaciones.

