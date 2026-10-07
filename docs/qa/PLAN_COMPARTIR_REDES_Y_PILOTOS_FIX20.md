# Compartir y publicar fuera de KOMBAX: propuesta de integración

7 octubre 2026. Propuesta pendiente de implementación; no describe funcionalidades ya entregadas en FIX19.

Objetivo: compartir publicaciones públicas de Social, eventos públicos y productos públicos de Showcase con retorno a su ficha concreta en kombax.es.

## Vía 1: compartir con confirmación en la red

- Un único componente Compartir reutilizado en Social, Events y Showcase.
- Enlace permanente por contenido, previsualización con título, imagen y descripción y retorno al elemento exacto después del acceso cuando sea necesario.
- X, Facebook y Threads: abrir el flujo de composición compatible, con enlace a KOMBAX, y confirmación final del usuario en la red.
- Instagram y TikTok: exportar/compartir medios compatibles y texto con enlace; alternativa de descarga si el navegador no comparte archivos. Preparar formatos de publicación e historia cuando estén admitidos, sin prometer que un navegador pueda forzar el destino nativo.
- Un enlace escrito en una imagen o en el texto de una publicación no garantiza un enlace pulsable. Ofrecer QR y dirección legible; el enlace pulsable o sticker depende de la red y sus permisos.
- No exportar contenido privado/restringido. Si se retira/elimina, la ficha de KOMBAX dejará de mostrarlo. Las copias ya publicadas en otras redes no desaparecen automáticamente.

## Vía 2: cuentas conectadas

- Conexiones por identidad KOMBAX, no por la primera organización de una cuenta con varios perfiles.
- OAuth oficial por red, tokens únicamente en backend y acceso limitado al propietario o rol autorizado de comunicación.
- Revisar aplicación de desarrollador, tipo de cuenta elegible, permisos concedidos, formatos y aprobación de cada proveedor antes de mostrar la opción como operativa.
- Vista previa y confirmación del usuario; cola con idempotencia, estados pendiente/publicando/publicado/error, identificador remoto y opción de desconectar. No etiquetar como publicado antes de recibir confirmación del proveedor.
- No prometer publicación en perfiles personales o historias cuando el proveedor no la admite.
- No se han creado ni conectado aplicaciones de Meta, X o TikTok en esta revisión. Falta comprobar/provisionar esas aplicaciones y sus permisos para cerrar la publicación directa.

## Situación actual encontrada

Social usa navigator.share con enlace genérico a /#social. Showcase puede compartir visitar_url, que puede ser un destino externo. Events ya genera gráficos cuadrados e historias, con compartición de archivo o descarga. No se encontró una integración general de publicación OAuth a las cinco redes en estos módulos.

## Verificación piloto realizada

Proyecto Supabase poggsobhtutbuagjiydc. Pruebas reales con rol authenticated y transacciones revertidas:

- Los próximos cinco Competidores se autorizan automáticamente: cada uno pudo editar sus datos públicos y publicar después de aceptar las normas. El sexto no recibe la excepción. Se conservaron los controles de edad. SQL: supabase/tests/pilot-competitor-publication-edit-live-rollback-fix20.sql.
- Sant Pedro urban warrios, Urban Warriors y Doragon Santa Coloma pudieron guardar una edición de su perfil público y crear una publicación Social con su cuenta administradora. SQL: supabase/tests/pilot-club-publication-edit-live-rollback-fix20.sql.
- Al cierre: cero plazas Competidor consumidas, cero usuarios QA restantes y tres clubes piloto activos. No hubo publicaciones externas, compras ni cobros. Estas pruebas de datos no incluyen una subida real de imágenes al almacenamiento.

Fuentes oficiales consultadas:
- https://docs.x.com/x-for-websites/web-intents/overview
- https://developers.tiktok.com/docs/en/content-posting-api-get-started
- https://www.postman.com/meta/workspace/instagram/documentation/23987686-9386f468-7714-490f-9bfc-9442db5c8f00

La documentación web de Meta respondió 429 durante esta revisión. Sus detalles de configuración deberán verificarse al integrar cada proveedor.
