# Auditoría operativa Urban Warriors 1.3.1

## Alcance

Se ha revisado el circuito completo de los módulos de alta y edición de alumnos, preinscripciones, disciplinas, grupos y horarios, sesiones, asistencia, tarifas, cuotas, pagos, justificantes, publicaciones, material, documentos, notificaciones y renovación de sesión.

## Mejoras aplicadas

- Alta directa de alumnos mediante una RPC transaccional y validación de disciplina/grupo.
- Creación y edición de grupos con uno o varios horarios semanales.
- Validación de días, horas y solapamientos de horarios.
- Confirmación visible después de guardar, cierre del formulario y retorno automático a la lista correspondiente.
- Etiquetas más claras para diferenciar alta directa de alumno y preinscripción pública.
- Recarga de datos desde Supabase después de cada mutación.
- Auditoría SQL ejecutable por dirección mediante `app_auditoria_operativa`.
- Validaciones estáticas para todos los circuitos principales.

## Estado por módulo

| Módulo | Estado del código | Dependencia externa |
|---|---|---|
| Preinscripciones y aprobación | Preparado | Supabase/RLS |
| Alta y edición directa de alumno | Corregido | Migración 008 |
| Disciplinas y grados | Preparado | Supabase/RLS |
| Grupos y horarios | Corregido | Migración 008 |
| Sesiones y asistencia | Preparado | Supabase/RLS |
| Tarifas y generación de cuotas | Preparado | Funciones SQL previas |
| Cobros y justificantes | Preparado | Storage privado |
| Publicaciones y eventos | Preparado | Bucket `club-public-media` |
| Material y stock | Preparado | Bucket `club-public-media` |
| Documentos del alumno | Preparado | Bucket `member-documents` |
| Notificaciones internas | Preparado | Supabase |
| Push con la app cerrada | Estructura preparada | Firebase pendiente |

## Prueba real recomendada

Tras aplicar la migración 008 y publicar el parche, se debe recorrer en este orden: disciplina, grupo con dos horarios, alta directa, preinscripción y aprobación, tarifa, cuota, cobro, publicación con imagen, material con imagen, documento, asistencia y notificación.
