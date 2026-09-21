# Checklist local · R23

1. Descomprimir R23 en carpeta nueva; no mezclar con R22.
2. Abrir CMD en la raíz donde está `package.json`.
3. Ejecutar `npm ci` (o `npm install` si procede) y después `npm run dev`.
4. Abrir la URL indicada, normalmente `http://127.0.0.1:4173`.
5. Entrar en KOMBAX Events > Urban Warriors · Interclub de Jiu-Jitsu.
6. Confirmar visualmente:
   - 10 retratos visibles en participantes;
   - Malik/Bruno visibles en Main Event;
   - todas las parejas visibles en Fight Card;
   - sin iconos de imagen rota;
   - volver atrás/entrar de nuevo no rompe imágenes;
   - otros eventos mantienen sus imágenes.
7. Android Studio: abrir `android`, hacer Gradle Sync y generar APK Signed release con el keystore existente.
8. Instalar APK Signed y repetir Main Event/Fight Card/participantes.

Nota: versionCode sigue en 20101. Para subir a Google Play debe comprobarse antes si 20101 ya está ocupado.
