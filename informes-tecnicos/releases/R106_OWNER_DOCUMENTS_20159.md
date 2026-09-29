# KOMBAX R106 · build 20159

## Cambios

- Bandeja documental privada y clasificada en Owner.
- Lectura de PDF, hojas de cálculo, documentos e imágenes por los agentes Owner.
- Acciones rápidas de un toque.
- Creación auditable de borradores de informes del piloto.
- Botón persistente para cerrar la sesión de administración.
- Diseño responsive para escritorio, tablet y móvil.

## Migración

`294_kombax_owner_document_inbox_r106.sql`

## Despliegue backend

Volver a desplegar `kombax-owner-agents-r105` después de aplicar la migración 294.

## Rollback

Ocultar la bandeja en frontend y restaurar la Edge Function R105. No eliminar documentos ni tablas durante el piloto; conservarlos para trazabilidad.
