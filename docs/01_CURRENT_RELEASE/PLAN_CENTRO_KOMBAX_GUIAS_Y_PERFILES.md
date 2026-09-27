# Plan de reconstrucción · Centro KOMBAX

## Objetivo

Reunir en una sola ventana las instrucciones para usar KOMBAX, las guías de conocimiento deportivo en España, las fichas territoriales y KOMBAX Consultoría. La barra lateral mostrará **Recursos KOMBAX** como un acordeón que se abre con un clic. La marca visible será **KOMBAX** en todos los apartados.

Este plan parte del paquete acumulativo facilitado como fuente de verdad. La revisión del código y del catálogo detecta 19 guías temáticas públicas, 19 fichas territoriales activas y 15 entradas antiguas inactivas. El manual de gestión de clubes es un producto privado distinto de las guías públicas.

## 1. Nueva biblioteca de conocimiento

Las 19 guías temáticas se reconstruirán en **tres guías de consulta**, con índice interior, capítulos breves, enlaces entre temas, listas de comprobación y una página inicial de «qué necesito resolver». El texto «Cómo leer KOMBAX Guías» pasará a ser una explicación breve en el Centro KOMBAX y en la apertura de cada guía. Las fuentes y las advertencias específicas se conservarán junto al tema al que se refieren.

| Nueva guía | Contenido actual que integra | Recorrido del lector |
| --- | --- | --- |
| **Poner en marcha y dirigir un club** | Crear un club; vida y obligaciones anuales; personal y voluntariado; menores; datos, imagen y comunicaciones; seguros y responsabilidad | Elegir forma, constituir, organizar la temporada, cuidar a las personas y mantener las evidencias al día. |
| **Federaciones, licencias e interclubs** | Federaciones y oficialidad; licencias; interclub; combates y participantes; deportistas extranjeros | Entender el carácter oficial de la actividad, verificar la licencia aplicable y preparar encuentros entre clubes sin clasificar mal el evento. |
| **Organizar un evento de principio a fin** | Planificación; recinto y autorizaciones; salud y seguridad; entradas y accesos; patrocinio; expediente del organizador; cierre posterior | Decidir qué tipo de evento se celebra, preparar recinto y equipo, abrir al público, documentar y cerrar. |

**Regla editorial:** trasladar cada tema íntegro antes de recortar; eliminar repetición de portadas, glosarios, avisos y explicaciones generales; conservar matices territoriales, fuentes y supuestos en los que se necesita verificación. Revisar las referencias cruzadas antiguas por nombre de tema y no por códigos de edición. Los textos que dependen de ley, federación, recinto o aseguradora se contrastarán con su fuente antes de publicar la nueva colección; la mera unión de PDFs no se considerará una reconstrucción suficiente.

Las **19 fichas territoriales** seguirán siendo fichas independientes porque sus requisitos no son intercambiables. En la pantalla inicial aparecerá un selector «Elige tu comunidad o ciudad autónoma» en lugar de 19 tarjetas. Cada ficha enlazará desde el capítulo al que afecta. Una revisión editorial comprobará qué datos son estatales, autonómicos, federativos o propios de un recinto para evitar que una regla local parezca general.

## 2. Guías para usar el software

Cada guía de uso se escribirá desde tareas reales: dónde entrar, qué permiso hace falta, qué verá la persona, qué guardar, cómo comprobar que terminó y qué hacer si falta una función. Habrá versión web navegable y PDF descargable; ambas saldrán del mismo contenido fuente. Las funciones sujetas a plan o capacidad se mostrarán como condicionales, sin prometer acceso universal.

| Guía | Recorridos mínimos que se documentarán |
| --- | --- |
| **Club y equipo de gestión** | Alta y acceso; dirección, coordinación, secretaría, economía, comunicación y monitor; socios e inscripciones; grupos, sesiones, asistencia y progreso; finanzas; documentos; equipo y permisos; federación y licencias; Events, Showcase, Social, asistencia y migración. Incorporar lo aparecido después del manual anterior. |
| **Federación** | Crear y gestionar identidad; afiliación de clubes; equipo federativo; licencias; calendario y eventos; comunicación; cobros y servicios habilitados; límites de acceso a datos privados del club. |
| **Marca** | Perfil de marca; catálogo y Showcase; campañas, colaboraciones y patrocinios; oportunidades; eventos; equipo, métricas y cobros cuando estén habilitados. |
| **Competidor** | Identidad deportiva; disponibilidad y oportunidades; preparación de competiciones; licencias; Fight Cards, historial, Social y colaboraciones. Competidor mantiene su guía propia. |
| **Profesional** | Inicio y configuración de «Mi actividad»; servicios, agenda, clientes o representados según especialidad; autorizaciones, licencias, Events, finanzas y cobros. Añadir recorridos específicos para entrenador, manager, sanitario, árbitro/juez y promotor/organizador. |
| **Espectador** | Cuenta, descubrimiento, Social, Showcase, Events, guardados, avisos, entradas y límites de publicación o compra. |
| **Miembro, alumno y familia** | Acceso al club, horarios, solicitudes, cuotas, comunicaciones, asistencia, perfil y autorizaciones. Separar lo que puede hacer un menor y lo que corresponde a su familia. |
| **Media / creador** | Alta de identidad, presentación pública y flujos realmente disponibles de Social, Events y contenido; documentar únicamente capacidades verificadas en la versión activa. |

**Matriz de verificación por pantalla:** ruta de acceso, perfil y permiso, estado vacío, acción principal, confirmación, error frecuente, vista móvil, efecto en otros perfiles y enlace a ayuda. El inventario actual muestra rutas del club en `web/js/app.js` y entornos de Federación, Marca, Competidor, Profesional y Espectador en `web/js/modules/managed-profile-hub.js`; el acceso global añade Media / Creador. La guía no se dará por terminada a partir de nombres de módulos: habrá que recorrer los flujos con cuentas de prueba y permisos distintos.

## 3. Centro KOMBAX y barra lateral

**Barra lateral:** un solo bloque «Recursos KOMBAX» con icono, descripción corta y chevrón. Un clic abre o cierra el acordeón; la elección se recuerda. Sus accesos serán «Aprender a usar KOMBAX», «Conocimiento deportivo», «Territorios de España» y «KOMBAX Consultoría». En móvil conservará el mismo orden y una superficie táctil cómoda.

**Ventana única:** ruta propuesta `#resources`, con encabezado común y cuatro paneles de acordeón. Solo uno se abre al seleccionar otro para reducir el ruido visual. La búsqueda cubre títulos y tareas; un filtro de perfil ordena las guías de uso, y el selector territorial aparece solo donde corresponde. Una ficha muestra propósito, público, tiempo aproximado y acciones «Leer» y «Descargar». Consultoría mantiene su flujo actual de servicios y solicitudes dentro de este marco visual, sin mezclar las guías de acceso privado con las públicas.

**KOMBAX Social:** su acceso principal en la barra lateral llevará un icono cuadrado con esquinas suaves, borde luminoso y halo LED propio. Se comprobarán los estados normal, seleccionado, teclado y móvil; el brillo no debe sustituir el texto ni dificultar la lectura.

**Contenido comercial:** quitar códigos de edición, fechas de producción y referencias internas de las portadas y fichas destinadas al usuario. En contenido normativo, mantener una explicación clara de la vigencia y de lo que significa «por confirmar», con enlace a la fuente competente. El manual privado no se moverá a los assets públicos hasta que exista control de acceso.

## 4. Secuencia de trabajo

1. **Congelar inventario.** Registrar todas las rutas, perfiles, capacidades, guías, fichas, enlaces y fuentes actuales. Resultado: matriz de trazabilidad entre versión existente y destino nuevo.
2. **Reconstruir los tres textos de conocimiento.** Unificar, editar duplicaciones, reescribir referencias cruzadas, añadir índices y tablas de decisión; contrastar los puntos normativos y territoriales. Resultado: tres fuentes editables y tres PDFs accesibles.
3. **Redactar las guías de uso por perfil.** Empezar por Club, Federación y Marca; seguir con Competidor, Profesional, Espectador, Miembro/Familia y Media/Creador. Cada capítulo se valida en el software y en móvil. Resultado: guía web y PDF por perfil, con variantes de rol donde proceda.
4. **Construir el Centro KOMBAX.** Crear el acordeón único, búsqueda y filtros; integrar las tres bibliotecas, las 19 fichas y Consultoría; mantener redirecciones desde accesos anteriores. Resultado: una ventana coherente sin tarjetas repetidas.
5. **Pulir la navegación visual.** Aplicar el icono LED cuadrado de Social, contraste, estados de foco y comportamiento responsive. Resultado: navegación consistente en escritorio y móvil.
6. **Certificar y empaquetar.** Comprobar enlaces y descargas, búsquedas, permisos y privacidad, PDF y web, teclado, móvil, sin regresiones en Social, Events, Showcase, Consultoría ni acceso privado al manual. Actualizar versión y manifiesto, y generar ZIP acumulativo verificable.

## 5. Criterios de aceptación

- La pantalla inicial muestra **tres** guías temáticas, no 19 tarjetas; las 19 fichas territoriales se encuentran mediante un selector.
- Toda la biblioteca y Consultoría se abren desde **Recursos KOMBAX** en una sola ventana; el acordeón funciona con un clic y teclado.
- Cada perfil dispone de una guía de uso que reproduce sus capacidades reales, permisos y límites; la de Club incluye las funciones actuales que faltan en el manual anterior.
- No quedan referencias a códigos de guías retiradas en el texto dirigido al usuario; ningún tema o fuente se pierde en la síntesis.
- Los datos «por confirmar» explican qué debe verificarse y ante quién; los puntos normativos están revisados para el territorio correspondiente.
- El manual privado sigue protegido; KOMBAX Social tiene icono cuadrado con luz LED y texto legible.
- El paquete final contiene fuentes editables, PDFs, índices, notas de cambios y comprobación de integridad.

## Estado de la implementación R92

El **manual premium de gestión de clubes** se conserva como producto privado. Las tres guías públicas consolidadas, las nueve guías de uso por perfil y el Centro KOMBAX están implementados en la fuente web, en `dist` y en los assets Android. Los 18 temas anteriores permanecen archivados para trazabilidad; el índice activo ofrece tres volúmenes y 19 fichas territoriales.

La colección editorial conserva el contenido y las fuentes de la edición facilitada como fuente de verdad. No se ha efectuado una nueva revisión jurídica independiente de cada regla autonómica o federativa, ni un despliegue remoto. El informe de release R92 registra las comprobaciones realizadas y cualquier límite de publicación.
