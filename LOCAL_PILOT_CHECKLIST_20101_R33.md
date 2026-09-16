# KOMBAX R33 · Checklist piloto local

1. Descomprimir el ZIP en una carpeta nueva.
2. Ejecutar `npm ci`.
3. Ejecutar `npm test`.
4. Ejecutar `node scripts/build.mjs`.
5. Ejecutar `npm run dev` y validar Mi Club, Mi Federación, Mi Competidor y Mi actividad.
6. Caso crítico: Club con Federación A/B; verificar que cada Federación solo ve lo suyo.
7. Probar invitación de Presidencia/Secretaría/Tesorería/Coordinación/Junta/Colaborador.
8. Probar adjunto PDF/JPG/PNG, compartir explícitamente, abrir URL temporal y revocación.
9. Para Android, copiar `android/keystore.properties.example` a `android/keystore.properties` y completar con la clave local existente.
10. Generar primero APK para prueba física y después AAB para Play.
11. Antes de subir Play, confirmar versionCode disponible.
