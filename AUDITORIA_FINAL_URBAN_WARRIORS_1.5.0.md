# Auditoría final de código — Urban Warriors 1.5.0

## Corregido

- Familias con varios menores mediante relaciones independientes tutor–socio.
- Posibilidad de más de un tutor por menor y conservación del contacto principal.
- Matrículas simultáneas en varias disciplinas.
- Matrículas simultáneas en varios grupos de una misma disciplina.
- La aprobación de una nueva preinscripción ya no desactiva otras disciplinas.
- Control de duplicados por alumno, disciplina y grupo.
- Aforo contado por alumnos únicos.
- Solicitud adicional de matrícula para un alumno ya existente.
- Firebase Cloud Messaging web y Android preparado.
- Registro de token, renovación, canal Android y apertura de ruta desde push.
- Firma release desacoplada mediante secretos de entorno.

## Límites de la certificación

Las pruebas incluidas verifican sintaxis, contratos y construcción local. La entrega no puede certificar el envío real de FCM, las reglas del proyecto Supabase desplegado ni una APK firmada hasta que el propietario añada las credenciales externas y ejecute la prueba real indicada en `PRUEBA_ACEPTACION_FINAL_1.5.0.md`.
