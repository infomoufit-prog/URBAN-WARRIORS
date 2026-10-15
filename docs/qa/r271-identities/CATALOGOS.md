# Material y Showcase: vistas del catálogo

Implementado en código local, todavía sin despliegue ni nuevo ZIP:
- Cuadrícula compacta, cuadrícula grande y lista en Material del club y exploración de Showcase.
- Vista compacta predeterminada; preferencia guardada por cuenta. Material también separa la preferencia por club.
- Material: marco de imagen 1:1 y encuadre completo predeterminado; se conservan los ajustes de imagen existentes.
- Showcase: se conserva su marco 1:1.
- Cambio de vista sin recargar, ordenar de nuevo ni perder productos y filtros.
- En móvil: compacta de dos columnas, grande de una y lista con miniatura cuadrada.

QA: 14 comprobaciones de preferencias y aislamiento; 12 combinaciones visuales de catálogos/modos/móvil-escritorio con ocho productos simulados. Imágenes cargadas, proporciones cuadradas y sin desbordamiento horizontal. Se conservó la comprobación de visibilidad/moderación de Showcase, simulando sus respuestas en la prueba.

No se hicieron compras, cargos, publicaciones ni cambios en datos de producción. No se ha generado ni entregado un ZIP nuevo; continúa en pausa por indicación del usuario.

Regresión acumulativa final: 116 suites correctas, 3 incidencias de traducción heredadas y 0 fallos nuevos. Compatibilidad Linux: 390 archivos JavaScript y 950 importaciones verificadas. Recursos web/dist/Android idénticos.
