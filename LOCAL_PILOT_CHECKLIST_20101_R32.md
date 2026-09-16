# Checklist local antes de GitHub / Netlify

## A. Prueba local web/PWA
Desde la raíz del ZIP descomprimido:

```bash
npm ci
npm test
node scripts/build.mjs
npm run dev
```

Abrir `http://127.0.0.1:4173`.

Validar manualmente al menos:
- login y Gateway;
- cambio de identidad;
- Mi Club;
- Mi Competidor;
- Mi Federación;
- Mi Marca;
- Mi actividad Profesional;
- Espectador;
- Social;
- Showcase;
- Events;
- Finanzas Profesionales si la capability está activa;
- Privacidad/Soporte.

## B. Android Signed
1. Abrir la carpeta `android` con Android Studio.
2. Crear `android/keystore.properties` desde el ejemplo o configurar las variables `UW_*`.
3. Usar la misma upload key ya vinculada al proyecto Play.
4. Generar APK signed para dispositivo y AAB signed para Play cuando proceda.
5. Instalar APK en móvil real.
6. Repetir los flujos críticos anteriores y comprobar push/notificaciones.

## C. Antes de GitHub
Comprobar que NO existen dentro del repositorio:
- `android/keystore.properties`
- `*.jks`
- `*.keystore`
- `.env`
- claves PEM/P12.

## D. GitHub / Netlify
No se ha realizado push ni deploy durante R28-R32.
Solo después de tu validación local:
1. publicar tú el candidato mediante GitHub Desktop;
2. desplegar en Netlify según tu flujo habitual;
3. ejecutar smoke del dominio publicado;
4. si el frontend cambia después, regenerar Android antes de marcar una build móvil como equivalente.
