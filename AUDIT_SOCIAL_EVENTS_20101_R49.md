# Auditoría R49 · KOMBAX Social + KOMBAX Events

## Alcance auditado
R49 parte de R48. Antes de modificar se verificó que R48 ya contenía Main Event, Co-Main Event, cartelera estructurada, cartel gráfico de Fight Card y fallbacks de peleadores sin fotografía. R49 no duplica esa arquitectura.

## Hallazgos KOMBAX Social
1. El contador de `likes_count` se estaba presentando como “intereses”, mezclando concepto público y señal privada.
2. La preferencia R47 existía, pero era necesario desacoplarla del contrato de Like de forma explícita en backend.
3. Faltaba aviso visible de red temática y motivo específico de moderación por contenido ajeno a artes marciales/deportes de contacto.

## Correcciones
- Like público usa `kombax_social_likes` y ❤️.
- Preferencia privada usa `kombax_social_preferencias_usuario_v237` y 👍/👎.
- Feed v238 devuelve `liked_by_me` e `interest_by_me` como señales independientes.
- `fuera_tematica` se añade al sistema de reportes existente; no introduce borrado automático.

## Hallazgos KOMBAX Events
La estética premium R48 se renderiza desde componentes comunes, por lo que los eventos existentes heredan los cambios visuales sin tener que ser recreados. R49 añade interacción al poster sin alterar el modelo de datos.

## Regla visual de combates preservada
Todo combate conserva presencia visual aunque no tenga fotos:
- con fotos de ambos peleadores: face-off;
- con arte/cartel: uso de cartelera gráfica;
- sin fotos/arte: fallback premium con nombres, VS y metadatos.

## Conclusión
No se detectó necesidad de DDL nuevo para Events. La única migración R49 corresponde a la separación Social Like/Preferencia y a moderación temática.
