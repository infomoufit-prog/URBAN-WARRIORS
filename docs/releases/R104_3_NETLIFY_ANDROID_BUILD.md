# KOMBAX R104.3 — cierre de empaquetado web y Android

Fecha: 28/09/2026. Base acumulativa: R104.2, build 20156. No modifica datos ni funciones comerciales.

## Cambios

- User-Agent de Android alineado con el build 20156; era 20155 y bloqueaba una prueba del despliegue Netlify.
- Fuente de `health` alineada con 20156. Función Edge desplegada en el proyecto piloto como versión 39; lectura de configuración confirmada. La respuesta HTTP externa no se pudo comprobar desde este entorno.
- `release:build` de Netlify ejecuta control legal, 59 scripts de QA y build. Resultado local: 52 PASS, 7 fallos P2 conocidos de i18n y aserciones históricas de onboarding, 0 fallos nuevos. La suite estricta `npm test` sigue fallando por esos 7; el gate de Netlify los informa y solo permite los patrones y máximos ya identificados.
- Scripts Android actualizados: nombres R104.3 derivados de `versionCode`, preparación web antes de release, APK release y AAB Play en el mismo proceso. Se mantiene el identificador `com.urbanwarriors.app` para continuidad de instalación.
- Preflight Android verifica coincidencia de build web/Android, Java compatible, Firebase y firma sin mostrar contraseñas.

## Netlify

Subir el contenido de este ZIP como raíz del repositorio. `netlify.toml` fija `npm run release:build` y publicación de `dist`. No sustituir por `npm run build`, que utiliza la suite estricta completa y hoy falla en 7 P2 declarados. Verificar en el log `52 PASS, 7 P2 conocidos, 0 fallos nuevos` y `OK build 615 archivos`. Validar el sitio publicado y Supabase desde navegador después del despliegue; ese paso depende del despliegue del propietario.

## Android Studio y Google Play

Abrir la carpeta `android` como proyecto. Configurar **Gradle JDK 21** (instalado en este equipo en `C:/Users/Bryan Work/.jdks/jbr-21.0.11`) o JDK 17. El JBR 25 de Android Studio no está soportado para ejecutar Gradle 8.11.1. Gradle 8.11.1 y Android Gradle Plugin 8.10.1 son la pareja prevista para API 36.

Para actualizar una app ya publicada se necesita **la misma clave de subida** registrada en Google Play. No incluir `.jks`, `keystore.properties` ni contraseñas en GitHub o en el ZIP. Para el script de release, copiar `android/keystore.properties.example` a `android/keystore.properties`, completar los cuatro valores locales, y ejecutar `node scripts/android-play-bundle.mjs` con Node disponible. El script genera una APK release firmada para instalación de prueba y un AAB firmado para Play. Android Studio también permite `Build > Generate Signed Bundle / APK`; para Play elegir **Android App Bundle**. `versionCode` actual: 20156; comprobar en Play Console que sea mayor que cualquier versión ya subida.

## Evidencia y límites

- Build web local: PASS, 615 archivos idénticos entre `web`, `dist` y los assets Android.
- Preflight Android local: 6/7 PASS; falta clave de firma local, excluida deliberadamente del ZIP.
- Compilación Gradle local: NO VERIFICADA. Este ejecutor devuelve `Unable to establish loopback connection` incluso con Java 21 y red autorizada; no se obtuvo APK/AAB nuevo ni se verificó su firma.
- La publicación Netlify y la aceptación por Play Console: NO VERIFICADAS, corresponden a los pasos de despliegue del propietario.
- El ZIP R81 suministrado como referencia mantiene el mismo plugin, Gradle, SDK, dependencias y estructura de firma que esta base; su principal diferencia Android es el build 20134.

No declarar esta release certificada para Google Play hasta compilar el AAB con la clave correcta, verificarlo e instalar/probar la APK release en dispositivo.
