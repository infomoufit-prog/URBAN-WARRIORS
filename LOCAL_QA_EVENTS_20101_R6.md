# QA LOCAL - KOMBAX Events 20.101 R6

## 1. Recuperación de filtros
1. Entrar en KOMBAX Events.
2. Debe aparecer `Noche de Impacto · Barcelona` sin tocar nada.
3. Pulsar `Resultados` -> puede quedar vacío porque el evento todavía es próximo.
4. Pulsar `Todos` -> el evento debe reaparecer inmediatamente.
5. Pulsar `Torneo` -> puede quedar vacío.
6. Pulsar `Mostrar todos los eventos` -> la cartelera completa debe volver.
7. Salir a Social y volver a Events -> la vista debe empezar otra vez en Todos.

## 2. Filtros válidos del evento de Barcelona
El evento debe aparecer en:
- Todos
- Próximos
- Inscripciones
- tipo Velada (si el estado no lo contradice)

No debe aparecer en:
- En directo
- Resultados

## 3. Crear evento como Urban Warriors
1. Entrar con la cuenta de Dirección / Gestor del club Urban Warriors.
2. Abrir KOMBAX Events.
3. En el hero debe aparecer `Crear evento`.
4. Pulsarlo.
5. Debe abrir el editor completo del evento público.
6. Crear una ficha de prueba o cancelar sin guardar.

## 4. Aislamiento
El selector `Organiza como` desde el workspace Urban Warriors debe ofrecer el club activo autorizado, sin mezclar otra federación o club como identidad creadora.

## 5. Android
Tras generar APK signed desde esta misma fuente:
- repetir los puntos 1-4;
- comprobar que el scroll de filtros es táctil;
- comprobar `Todos los tipos` y `Mostrar todos los eventos`;
- abrir `Crear evento` y revisar el formulario en vertical y horizontal.
