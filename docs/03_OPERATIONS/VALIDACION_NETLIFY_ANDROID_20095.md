# Validación controlada · Netlify + Android · KOMBAX 20.095

Use **only this 20.095 source**. Do not combine files/runbooks from earlier builds.

## A. PC / source integrity

1. Descomprimir el ZIP 20.095 en una carpeta nueva.
2. Confirmar el SHA-256 externo del ZIP con el `.sha256` entregado.
3. Ejecutar `npm install` si el entorno no tiene dependencias preparadas.
4. Ejecutar `npm test` y `npm run build`. Ambos deben pasar.
5. Confirmar el mensaje `OK build 101 archivos · web = dist = Android`.

## B. Netlify

1. Subir 20.095 al repositorio con GitHub Desktop cuando decidas promoverla.
2. Netlify debe publicar `dist/` con `npm run release:build`.
3. Validar `https://kombax.es/`, login, KOMBAX Social, Showcase, Mi Club y Finanzas.
4. Validar un enlace público `https://kombax.es/?event=<slug>` sin iniciar sesión.
5. Validar `?event=<slug>&fight=<uuid>` y que destaque el combate correcto.
6. Abrir un highlight/foto/vídeo, dejar la página abierta o forzar un fallo de red, recuperar conexión y comprobar reintento/renovación sin romper la ficha.
7. Confirmar que el bucket nunca expone una URL pública permanente.
8. Solo después, sincronizar la Edge Function `health` del paquete para que anuncie build 20095.

## C. Android signing

1. En `android/`, crear `keystore.properties` desde el ejemplo apuntando al **JKS existente**.
2. No crear una nueva clave.
3. Ejecutar `npm run android:preflight`; debe dar 5/5.
4. Abrir `android/` en Android Studio y generar APK release/AAB desde esta misma fuente 20.095.
5. Verificar package `com.urbanwarriors.app`, versionCode 20095 y certificado esperado.

## D. Android deep-link QA

Con la app instalada:

- abrir `https://kombax.es/?event=<slug>` y confirmar que no se pierde `event`;
- abrir `https://kombax.es/?event=<slug>&fight=<uuid>` y confirmar que no se pierde `fight`;
- comprobar enlace malformado: no debe inyectarse al WebView;
- comprobar dominio externo: debe salir del WebView.

`autoVerify` sigue desactivado. Para que Android abra KOMBAX automáticamente como App Link verificado, primero hay que obtener la huella SHA-256 real de **Play App Signing**, publicar `/.well-known/assetlinks.json` y validar el dominio.

## E. APK/AAB / Google Play

1. Instalar APK release sobre la app existente sin desinstalar.
2. Validar arranque, sesión, push, rotación, selector de archivos, Social/Showcase/Eventos/Finanzas.
3. Probar enlaces de Evento desde WhatsApp/Chrome/QR.
4. Generar AAB desde el mismo commit/fuente.
5. Subir a pista de prueba únicamente después de la validación APK.

No confundir `BUILD SUCCESSFUL` con certificación funcional.
