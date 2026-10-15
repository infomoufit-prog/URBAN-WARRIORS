# KOMBAX R272 acumulativo · Navegación y Ayuda

Contiene R271 completo y las mejoras R272. No es un parche. R271 se conserva por separado.

## Cambios

- Menú del club agrupado en siete áreas, filtradas por los permisos existentes. Comunicaciones y Comunidad del Club comparten área, manteniendo sus pantallas.
- Ayuda inicial para todos durante el alta y creación de identidades, con guías sin llamadas al modelo.
- Después, ayuda permanente solo en gestión de Club (equipo), Marca y Federación. Alumnos, miembros, familias, espectadores, competidores y profesionales no muestran el widget en su espacio habitual.
- 67 guías y propuestas relacionadas. Ayuda explica procedimientos; Assist consulta información autorizada; Migrations prepara la importación.
- Conversación conservada al navegar y cerrar/reabrir dentro de la misma identidad. Cambiar de identidad o cuenta reinicia el contexto. Recargar toda la página reinicia la conversación visible.
- Consulta IA explícita, separada de las guías, con derecho comercial/piloto comprobado en Supabase. Comparte los créditos y las asistencias vigentes; no añade una bolsa gratuita.

## Actualización

1. Guarda una copia del repositorio actual y tus archivos locales de firma/configuración.
2. Reunifica las cuatro partes con UNIR_KOMBAX_R272_NAVEGACION_AYUDA.cmd en la misma carpeta. El script verifica SHA-256.
3. Extrae el ZIP final y copia su contenido en la raíz del proyecto que actualizarás manualmente. No copies el ZIP dentro del repositorio.
4. La migración usage_help_paid_entitlement_r272 y kombax-assist-r38 v21 ya se aplicaron en el Supabase de KOMBAX. No necesitan nuevos secrets.
5. Para otro proyecto Supabase, revisa y aplica las migraciones correspondientes y despliega la función con sus dependencias _shared. Mantén verify_jwt=true.
6. Haz tú la actualización de GitHub y el despliegue de Netlify. Este trabajo no ha hecho push, commit, merge, PR ni despliegue Netlify.
7. Tras actualizar la web, recarga para recibir los archivos nuevos y comprueba con tu club. El backend no puede sustituir el frontend instalado.

No se ha generado una APK/AAB nueva. Los recursos Android se sincronizaron con web/dist; compilar y publicar requiere el proceso habitual y un código de versión no usado en Play.

## Resultado y límites

Gate de entrega: 121 PASS, 3 P2 de traducción heredados y 0 fallos nuevos. La suite estricta npm test continúa señalando esos P2. Ver docs/qa/r272/INFORME.md para distinguir pruebas reales, simuladas y pendientes.

No se han publicado contenidos, enviado invitaciones, ejecutado cobros ni hecho consultas reales al modelo para estas pruebas.
