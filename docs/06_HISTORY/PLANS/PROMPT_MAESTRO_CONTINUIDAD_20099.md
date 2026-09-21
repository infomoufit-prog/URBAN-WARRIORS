# PROMPT MAESTRO · CONTINUIDAD KOMBAX 20.099

Trabaja exclusivamente sobre **KOMBAX RC13 build 20.099 · Events Official Album + HD Media**.

Fuente de verdad: esta carpeta/ZIP 20.099. No volver a 20.098 salvo rollback explícito.

## Estado
- web/PWA/Android: 20099.
- Supabase Eventos: migraciones 159–176 aplicadas; 175/176 corresponden al álbum 20.099.
- JKS real incluido en `LOCAL_RELEASE_SIGNING/`; no crear otro keystore.
- contraseñas y `android/keystore.properties` no se guardan en el paquete.
- Netlify/Google Play no se despliegan automáticamente.
- health productivo permanece en la versión realmente desplegada hasta promover 20.099.

## Invariantes del álbum
- 15 fotos activas totales por evento.
- 5 vídeos almacenados activos por evento.
- vídeo de Eventos <=60 s, <=1080p, <=100 MB.
- fotos y vídeos pueden marcarse previo/evento/postevento.
- retirar libera plaza.
- Storage privado + signed URLs.
- vídeos externos HTTPS separados de la cuota de almacenamiento.
- no ampliar a 60 s los vídeos de Comunidad/Social sin decisión explícita.

## Seguridad
- gateway v175 delega en v173/v171 para conservar aislamiento de workspace.
- cuota backend 15/5 serializada por advisory lock.
- idempotencia endurecida por migración 176.
- Urban Warriors/Federación no se mezclan.
- Mi Club > Eventos no se mezcla con KOMBAX Eventos.

## QA siguiente
1. desplegar 20.099 controladamente cuando el usuario lo decida;
2. activar Urban Warriors post-deploy si aún no está activado;
3. crear un evento QA;
4. subir 15 fotos repartidas entre previo/evento/postevento;
5. intentar foto 16 y comprobar rechazo;
6. retirar una y comprobar que vuelve a permitir una foto;
7. subir 5 vídeos <=60 s y comprobar vídeo 6 rechazado;
8. probar vídeo >60 s y >1080p;
9. comprobar grid/lightbox en desktop y Android;
10. comprobar signed URL y contenido público anónimo.
