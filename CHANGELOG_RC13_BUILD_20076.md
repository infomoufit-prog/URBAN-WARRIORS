# RC13 build 20076 · Banner positioning

- Añadido editor de encuadre de banner por arrastre/táctil.
- Añadidos sliders X/Y y acción Centrar.
- El punto focal se guarda en Supabase, sin recortar destructivamente el original.
- El perfil canónico aplica `object-position` persistente.
- El alta de una nueva portada de Miembro muestra preview para encuadrar antes de guardar.
- Club, Marca, Federación y Competidor pueden reajustar su banner desde su perfil KOMBAX cuando tienen permiso de gestión.
- El perfil público dedicado del Club respeta el mismo punto focal.
- Eliminado el `object-position:center!important` que impedía aplicar posiciones personalizadas.
- Migraciones 131 y 132 aplicadas.
- Health actualizado a build 20076.
