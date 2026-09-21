# PROMPT MAESTRO DE CONTINUIDAD · KOMBAX 20.063

Actúa como arquitecto principal, desarrollador senior, QA y responsable de release de **KOMBAX / Urban Warriors RC13**.

## FUENTE DE VERDAD

Trabaja exclusivamente sobre:

**KOMBAX RC13 build 20063 · SOCIAL MESSAGING FINAL QA**

No regreses a builds anteriores salvo para investigar una regresión concreta. La build 20062 es únicamente la referencia desplegada en Netlify durante la validación móvil; no debe usarse como base para nuevas modificaciones.

## ESTADO OPERATIVO

- Build de trabajo: **20063**.
- Android: `applicationId com.urbanwarriors.app`, `versionCode 20063`, `versionName 2.0.0-rc.13`.
- Web/PWA/Android assets están sincronizados: 66/66/66 y 0 diferencias de hash tras `npm run build`.
- `npm test`: PASS.
- Regresión específica 20063: PASS.
- Netlify: **NO desplegar 20063 todavía**. Mantener la 20062 como versión web de referencia hasta freeze manual.
- APK signed 20063: debe generarse localmente con el JKS existente; el paquete no contiene secretos de firma.
- Supabase migración 107: preparada, con preflight remoto de dependencias correcto, pero **no aplicada live al cierre de este paquete**.

## CAMBIOS CONSOLIDADOS EN 20063

### Mensajería Social
- No existe acción visible `Cerrar chat`.
- La `X` sale de la conversación sin modificarla y detiene el poller de esa ventana.
- `Eliminar conversación` es la única acción destructiva de cierre/eliminación visible.
- Mantener histórico, envío, lectura, autosync, paginación y read receipts existentes.

### Comentarios
- Comentarios inline dentro de la publicación/contexto del feed.
- No abrir una segunda pantalla `Añadir comentario`.
- Conservar respuestas, borrar propio, denuncia, permisos, identidad y estados de comentarios.

### Mi red
- UX pública: `Mi red`, `Añadir a mi red`, `Aceptar en mi red`, `Eliminar de mi red`.
- No mostrar `Relaciones` como concepto de KOMBAX Social.
- La red sigue privada: sin conteo público, listado público ni métrica de popularidad.
- No renombrar tablas/RPC históricos solo por estética si aumenta riesgo de regresión.

### Badge de Mensajes
- Mensajes tiene icono y badge independiente.
- Click abre directamente la bandeja de Mensajes.
- El contrato v107 cuenta conversaciones con mensajes pendientes, no la suma de mensajes de cada hilo.
- No duplicar el contenido del chat dentro de Notificaciones KOMBAX.

### Social vs Showcase
- Una bandeja, filtros `Todos | Social | Showcase`.
- Diferenciación visual clara del canal Showcase.
- Cada conversación Showcase pertenece a un producto concreto.
- Mostrar imagen, nombre y marca del producto tanto en bandeja como en cabecera del hilo.
- Misma pareja + productos distintos = hilos distintos.
- Conservar snapshot del producto para mantener el contexto aunque la ficha cambie o se archive.

### CTA Showcase
- El contacto comercial se inicia desde el producto.
- `Consultar en Showcase` disponible cuando proceda.
- Primer mensaje sujeto a Contact Gate 10–500 caracteres.

## BACKEND 107

Migración canónica:
`supabase/migrations/107_kombax_social_showcase_messaging_20063.sql`

Soporte:
- `supabase/verification/preflight_107_kombax_social_showcase_messaging_20063.sql`
- `supabase/verification/107_kombax_social_showcase_messaging_20063_verification.sql`
- `supabase/rollbacks/107_kombax_social_showcase_messaging_20063_rollback.sql`

Mientras 107 no esté activo:
- Social debe seguir funcionando mediante fallback v104/v106.
- No simular el chat Showcase con datos locales ni reutilizar un hilo Social como sustituto.
- Showcase debe informar de forma humana que la actualización backend 107 es necesaria.

Cuando llegue el momento de activar 107:
1. volver a comprobar live/preflight;
2. aplicar la migración exacta versionada;
3. ejecutar la verificación 107;
4. ejecutar Security Advisor y Performance Advisor;
5. validar primero compatibilidad de la web 20062;
6. después validar APK 20063 con dos cuentas reales y al menos dos productos.

## INVARIANTES DE SEGURIDAD

No romper:
- RLS/ownership;
- aislamiento multiclub;
- Contact Gate y bloqueo 18+;
- bloqueos entre perfiles;
- moderación y auditoría;
- límites/guardas existentes de Social;
- recuperación/cambio de contraseña;
- recibos y finanzas;
- escalabilidad v106;
- package Android y firma existente.

Nunca incluir `service_role`, JKS, contraseñas, claves privadas ni `keystore.properties` real.

## REGLA DE ESTA ETAPA

Estamos en **validación final**, no en expansión de producto. Cada cambio nuevo debe clasificarse como bug, UX final, privacidad/seguridad, flujo funcional o estética final. Hacer la modificación mínima que resuelva el caso y ejecutar regresión antes de continuar.

No desplegar automáticamente a Netlify, no generar una nueva identidad Android, no crear un nuevo JKS y no modificar producción de forma destructiva.

## CHECKLIST DESPUÉS DE CADA INTERVENCIÓN

1. inspección de código real 20063;
2. test específico;
3. `npm test`;
4. `npm run build`;
5. confirmar `web = dist = Android`;
6. comprobar versionCode;
7. Android preflight;
8. secret audit;
9. si hubo SQL: preflight + verify + advisors;
10. validación manual Android;
11. actualizar changelog/continuidad;
12. generar ZIP + SHA-256.

## VALIDACIÓN MÓVIL PRIORITARIA

Orden:
1. Mi red.
2. Comentarios inline.
3. Mensajes Social: abrir/enviar/X/reabrir.
4. Eliminar conversación.
5. Badge de mensajes.
6. Solicitudes de contacto.
7. Social vs Showcase en bandeja.
8. Producto Showcase visible dentro del chat.
9. Dos productos distintos entre la misma pareja → dos hilos.
10. lectura/no leídos con dos cuentas.
11. pérdida/recuperación de red.
12. regresión general del resto de la app.

## FREEZE Y RELEASE

Solo tras aprobación manual:
- congelar build candidata;
- desplegar la build aprobada en Netlify;
- validar PWA;
- generar AAB signed con el mismo JKS;
- revisar versionCode y Play Console;
- subir a Google Play en el canal de prueba definido.

No declarar PASS, freeze, APK signed o deploy si no existe evidencia real.
