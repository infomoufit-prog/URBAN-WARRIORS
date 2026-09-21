# KOMBAX 20.101 · R44 · Combat Events Flow Stabilization

## Base preservada
R44 deriva exclusivamente de R43. R43 queda intacta como punto de retorno.

## Alcance
1. Auditar eventos vivos de Urban Warriors y comprobar integridad relacional.
2. Comparar el flujo de eventos demo con el flujo normal de creación/edición.
3. Eliminar clics silenciosos, cortes de navegación y aperturas fuera de orden.
4. Corregir la edición de eventos existentes sin perder el contexto organizador.
5. Invalidar de forma coherente la caché de detalle después de mutaciones.
6. Separar media sintética/demo de la media persistida que administra el gestor.
7. Mantener RLS/RPC/backend sin cambios DDL salvo que la auditoría demuestre necesidad.
8. Ejecutar pruebas Events históricas, R40/R42/R43, regresión completa y build/paridad.

## Riesgos identificados antes de implementación
- Un evento fuera de la cartelera actual podía producir un click sin respuesta.
- `Organiza como` está disabled al editar y por estándar HTML no entra en FormData.
- La caché local podía mostrar Fight Card/participantes/resultados anteriores hasta 60 s.
- El menú Gestionar evento instalaba listeners document-level sin lifecycle de cierre.
- Los seeds demo usan rutas locales `./assets/...` incompatibles con `input[type=url]`.
- El gestor de álbum mezclaba recursos demo sintéticos con registros realmente persistidos.
- Dos aperturas rápidas podían resolver en orden inverso y sustituir el modal correcto.

## Migraciones / backend
No se prevé migración DDL para R44. El dominio vivo ya presenta integridad relacional y los fallos encontrados son de lifecycle/estado/frontend. Se conserva el gateway productivo `app_kombax_eventos_mutate_v191` y bundle `app_kombax_evento_bundle_v189`.

## Criterio de cierre
R44 solo será candidata PRE-QA si:
- los eventos vivos no presentan referencias rotas;
- editar un evento existente conserva una identidad organizadora válida;
- abrir por ID no depende de discovery;
- mutaciones relevantes invalidan detalle;
- modal management limpia listeners al cerrarse;
- demo visuals no bloquean validación URL;
- manager de álbum administra solo datos persistidos;
- targeted R44 + regresiones Events + npm test + build/paridad finalizan sin errores.
