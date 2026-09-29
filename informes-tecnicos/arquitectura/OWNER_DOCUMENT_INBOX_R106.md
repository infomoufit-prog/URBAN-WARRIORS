# Owner Document Inbox · R106

## Objetivo

Ordenar los documentos que llegan a Administración KOMBAX y permitir que Owner Operations o Pilot Intelligence los analicen desde su contexto autorizado.

## Flujo

1. El Owner selecciona un título, categoría y uno o varios archivos.
2. El navegador valida formato y tamaño antes de subir.
3. El archivo se guarda en el bucket privado `kombax-owner-inbox`, dentro de la carpeta del Owner autenticado.
4. El registro queda en `kombax_owner_ai.documents` con estado `received`.
5. El Owner pulsa **Analizar operaciones** o **Analizar piloto**.
6. El backend vincula como máximo tres documentos al turno, marca `analyzing` y los envía como entrada de archivo o imagen a Responses API.
7. El resultado queda auditado en el turno. El documento pasa a `analyzed` o `failed`.
8. Cuando Pilot Intelligence propone `create_pilot_report`, se crea un informe en estado `draft` para revisión Owner.

## Formatos

PDF, TXT, CSV, TSV, XLS, XLSX, DOC, DOCX, PPT, PPTX, JPG, PNG y WEBP. Límite: 10 MB por archivo; 3 archivos por análisis; 18 MB por ejecución.

## Seguridad

- Bucket privado.
- Políticas Storage limitadas al usuario Owner y a la capacidad de administración de plataforma.
- Tablas del esquema privado sin permisos directos para `anon` o `authenticated`.
- El frontend no recibe la clave del proveedor de IA ni la clave de servicio.
- `store: false` en Responses API.
- Las operaciones irreversibles continúan requiriendo revisión humana y validación backend.

## Interfaz

La bandeja muestra categorías, estado, tamaño y fecha. Los botones de acciones rápidas envían la instrucción inmediatamente. La barra superior mantiene visible **Cerrar administración**.
