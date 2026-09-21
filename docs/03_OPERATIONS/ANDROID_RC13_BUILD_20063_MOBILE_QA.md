# ANDROID · KOMBAX RC13 build 20063 · MOBILE QA

## Estado del proyecto

- `applicationId com.urbanwarriors.app`
- `versionCode 20063`
- `versionName 2.0.0-rc.13`
- assets web sincronizados: OK
- Firebase: OK
- firma local: no incluida por seguridad

## Generación local

Usar Android Studio y el **mismo JKS de la app existente**. No crear otro keystore.

Ruta habitual:
`Build` → `Generate Signed App Bundle or APK` → `APK` → seleccionar el JKS existente → alias `urban-warriors` → variante `release`.

Después instalar el APK signed en el Android de validación y verificar que la aplicación instalada corresponde a `versionCode 20063`.

## Matriz móvil 20063

1. KOMBAX Social → Mi red.
2. Añadir a mi red / aceptar / eliminar.
3. Feed → Comentarios → escribir inline.
4. Mensajes → Social → abrir hilo.
5. Enviar mensaje → X → reabrir y comprobar persistencia.
6. Eliminar conversación y confirmar resultado.
7. Badge Mensajes con dos cuentas.
8. Abrir una conversación no leída y comprobar actualización del badge.
9. Activar backend 107 antes de la prueba Showcase E2E.
10. Showcase → producto → Consultar/Me interesa.
11. Confirmar imagen/nombre/marca en la bandeja y dentro del chat.
12. Segunda ficha entre las mismas identidades → hilo separado.
13. Filtros Todos/Social/Showcase.
14. pérdida y recuperación de Internet.
15. cierre/reapertura de app y persistencia.

## Nota de compilación de este paquete

El entorno de empaquetado actual no contiene la distribución Gradle 8.11.1 cacheada y no puede descargarla, por lo que no se genera ni se afirma un APK binario firmado desde este entorno. El preflight Android queda 4/5 exclusivamente por la firma local deliberadamente ausente.
