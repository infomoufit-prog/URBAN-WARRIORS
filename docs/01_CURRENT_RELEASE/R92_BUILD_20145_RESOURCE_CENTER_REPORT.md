# KOMBAX R92 · Informe de entrega

## Alcance realizado

- Centro Recursos KOMBAX en una sola ventana, con cuatro paneles de acordeón: uso del software, conocimiento, territorios y Consultoría. La barra lateral abre el grupo con un clic y recuerda la elección.
- Tres volúmenes públicos sustituyen la presentación fragmentada de las 19 guías temáticas anteriores. Integran los 18 temas de contenido; la guía de lectura pasa a la introducción. Las 19 fichas territoriales permanecen independientes y se consultan desde un selector.
- Nueve guías de uso por perfil: Club, Federación, Marca, Competidor, Profesional, Espectador, Alumno/Miembro, Familia y Media/Creador. Cada una permite lectura en la aplicación y descarga en PDF. El contenido editable único está en artifacts/guides-r100-1/usage-guides-source.json.
- Acceso al centro desde los perfiles directos y desde las rutas anteriores de Guías y Consultoría. Consultoría conserva sus servicios y solicitudes dentro de la nueva ventana.
- Icono cuadrado con halo LED para KOMBAX Social en la barra lateral. Interfaz del centro traducida en los ocho idiomas de la aplicación; el contenido editorial de las guías está en español y se señala al usuario.
- Manual premium de clubes conservado como producto privado. No se ha incluido en los archivos públicos web, dist o Android.

## Fuentes y límites

La base de esta entrega es el ZIP acumulativo R91 proporcionado por el usuario. Los volúmenes de conocimiento conservan los temas y fuentes de las guías públicas R100.1; se ha reorganizado su lectura y su presentación. Esta entrega no constituye una nueva auditoría jurídica independiente de cada disposición territorial. Las comprobaciones que dependan de una federación, administración, recinto o aseguradora se explican en el contenido y deben resolverse con la entidad competente antes de actuar.

Las guías de uso se escribieron a partir de las rutas, perfiles y módulos presentes en el paquete. Cuando una función depende de permisos, capacidad o plan, se presenta como condicional. No se ha validado cada recorrido con cuentas reales de todos los perfiles y permisos. No se ha desplegado a servicios remotos ni se han aplicado migraciones de base de datos.

## Evidencia de verificación

- Comprobación específica R92 de catálogo, fuentes, PDFs, rutas, acceso, icono y privacidad del manual.
- Suite acumulativa de 59 comprobaciones del paquete.
- Auditoría de traducciones: 1.658 claves completas en ocho idiomas y cero referencias sin resolver.
- Revisión de los 12 PDFs nuevos: texto extraíble y ninguna página vacía; inspección visual de portadas e índices representativos.
- Recorrido local de la nueva ventana: apertura del acordeón, lectura de Club, cambio de colección, selector territorial, Consultoría y barra lateral.
- Reconstrucción de web, dist y assets Android desde la misma fuente, con cotejo de archivos.

## Versión y continuidad

R92, build 20145, versión 2.0.0-rc.13-r92-resource-center. El ZIP de entrega es acumulativo y reemplaza los paquetes anteriores como fuente de continuidad local. Conserva web, dist, Android, iOS, Supabase, documentos, generadores, pruebas y los PDFs públicos.
