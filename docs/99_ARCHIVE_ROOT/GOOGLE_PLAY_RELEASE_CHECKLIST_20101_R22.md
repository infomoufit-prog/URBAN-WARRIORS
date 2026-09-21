# Google Play / Android release checklist · R22

R22 es actualmente una build de pruebas reales, no una release Play validada.

## Estado técnico actual
- applicationId: `com.urbanwarriors.app`
- versionCode: `20101`
- versionName: `2.0.0-rc.13`
- JKS de transferencia: presente en `LOCAL_RELEASE_SIGNING/`
- `android/keystore.properties`: ausente por diseño
- Signed APK/AAB R22: NO generado por esta entrega

## Antes de una subida futura a Google Play
1. Confirmar qué versionCode está ya ocupado en Play Console.
2. Incrementar versionCode si `20101` ya fue utilizado.
3. Restaurar/definir signing localmente.
4. Ejecutar preflight 5/5.
5. Generar AAB release Signed.
6. Verificar firma y package.
7. Instalar APK equivalente o validar bundle por pista de testing.
8. Repetir QA de Events/Social/Showcase.

No subir R22 a producción solo por pasar build/regresión; falta aceptación visual real y, para objetivos de escala, se recomienda un benchmark/load test representativo.
