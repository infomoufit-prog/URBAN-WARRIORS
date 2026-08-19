# KOMBAX RC13 build 20026 · Validación local y Android

## A. Abrir la PWA local
Desde la raíz del proyecto:

```bash
npm test
npm run build
npm run dev
```

Abrir `http://127.0.0.1:4173` en el navegador del ordenador. Para verlo en un móvil de la misma red, usar un servidor accesible desde LAN o el flujo local que ya utilices; no expongas secretos.

### Revisar visualmente
- Puerta KOMBAX: negro dominante + rojo visible, logo correcto, dos accesos.
- Directorio: Urban Warriors real, DEMO inequívocos, búsqueda/filtros.
- Login: Urban Warriors protagonista, KOMBAX como firma, teclado y safe areas.
- Shell: navegación, bottom nav, sidebar, tarjetas y responsive.
- Perfiles: iconos SVG propios; sin `CO/MA/FE/ES/PR`.
- Sin scroll horizontal en 390×844 y 412×915.

## B. Supabase
No ejecutar migraciones automáticamente desde este paquete.

El árbol `supabase/` mantiene las migraciones 037–042 y sus mecanismos de verificación/rollback heredados. Primero comprobar el estado real del proyecto Supabase autorizado y aplicar únicamente la secuencia necesaria.

## C. Preparar Android Studio
1. Abrir la carpeta `android` en Android Studio.
2. Copiar el `google-services.json` real a:
   `android/app/google-services.json`
3. Copiar:
   `android/keystore.properties.example`
   como:
   `android/keystore.properties`
4. Rellenar localmente `storeFile`, `storePassword`, `keyAlias` y `keyPassword` con el JKS existente. No enviar ni subir estos secretos.
5. Ejecutar desde la raíz:

```bash
npm run android:preflight
```

No generar la release definitiva hasta obtener 5/5.

## D. Firma y continuidad
- `applicationId` permanece `com.urbanwarriors.app`.
- `versionCode` es 20026.
- Debe usarse el mismo JKS/alias de la línea de releases existente para permitir actualización sobre la app instalada.

## E. Prueba física
Después de compilar una release firmada:
- Instalar como actualización sin desinstalar la versión vigente, si la firma coincide.
- Confirmar nombre/icono KOMBAX en launcher.
- Abrir puerta, directorio y Urban Warriors.
- Validar login, sesiones, comunidad, cuotas, recibos, notificaciones, Social y Showcase conforme a permisos.
- Validar push con Firebase real.
- Revisar notch/safe areas, teclado, back Android y orientación.

## F. Regla de parada
Si aparece un fallo de datos, permisos, RLS, tenant, firma o migración, no continuar con la siguiente capa hasta aislarlo. El rediseño no justifica cambiar SQL o contratos a ciegas.
