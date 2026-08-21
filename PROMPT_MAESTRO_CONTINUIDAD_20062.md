# PROMPT MAESTRO DE CONTINUIDAD · KOMBAX 20.062

## Fuente canónica
Trabaja exclusivamente sobre **KOMBAX / Urban Warriors · RC13 build 20062 · COMPETITOR REOPEN + FOUNDERS PROMO**.
No regreses a builds anteriores salvo para investigación comparativa de una regresión concreta.

## Estado operativo al cierre de esta continuidad
- Build técnico vigente: **20.062**.
- APK **signed** ya generada localmente en Android Studio y actualmente usada para validaciones manuales.
- El usuario informa que la versión web ya está **desplegada en delivery/Netlify**. Antes de afirmar URL, commit o deploy exacto, verificarlo en la plataforma correspondiente.
- Android applicationId se mantiene: `com.urbanwarriors.app`.
- Nombre visible del producto: **KOMBAX**.
- Keystore local existente: `urban-warriors-release.jks`.
- Alias de firma: `urban-warriors`.
- No compartir ni empaquetar contraseñas, keystores ni secretos.

## Cambios funcionales consolidados en 20.062
### Perfil Competidor
- Competidor vuelve a estar habilitado como identidad oficial.
- Puede solicitarse como identidad directa y conserva continuidad desde Miembro cuando corresponda.
- Backend de Competidor ya existía y seguía abierto; 20.062 reabre producto/UI sin crear una migración nueva.
- La validación de edad, propiedad, revisión y verificación KOMBAX se conserva.
- No romper Club / Marca / Federación / Miembro ni las reglas multiclub.

### Promoción fundadores
**Combat Social / KOMBAX Social**:
- Mostrar campaña para los **primeros 20 competidores verificados**.
- No publicar precio, descuento, porcentaje ni importe.
- Mensaje: tendrán una ventaja especial de lanzamiento cuando KOMBAX active su modalidad de suscripción; los detalles se comunicarán más adelante.

**KOMBAX Showcase**:
- Mismo concepto para los **primeros 20 clubes verificados**.

La elegibilidad debe poder auditarse por el orden real de eventos `verified`, usando `creado_en` y desempate determinista. No inventar una tabla promocional salvo que una necesidad futura lo justifique.

## Hallazgo manual pendiente de corregir
Durante validación en APK signed se encontró este fallo de UX en Contact Gate:
- Formulario: `Contactar con [identidad]`.
- El backend exige que el primer mensaje tenga entre **10 y 500 caracteres**.
- Con `Hola` el backend devuelve correctamente `KOMBAX_CONTACT_REQUEST_TEXT_INVALID`, pero la UI deja enviar y enseña al usuario el error técnico/RPC.

### Corrección requerida
1. Validar en frontend antes de llamar al RPC.
2. Deshabilitar/rechazar envío cuando el mensaje tenga <10 o >500 caracteres.
3. Mostrar mensaje humano, por ejemplo: `El primer mensaje debe tener entre 10 y 500 caracteres.`
4. No exponer nombres internos de RPC ni códigos técnicos en la interfaz.
5. Mantener exactamente la misma validación backend; no relajar seguridad ni contrato.
6. Añadir regresión automatizada para 9, 10, 500 y 501 caracteres.
7. Revalidar Social/Showcase Contact Gate y APK/PWA/browser.

## Estado técnico heredado que NO debe romperse
- Seguridad de cuenta y cambio/recuperación de contraseña.
- Multiclub isolation.
- RLS/RPC y cierres de bypass consolidados.
- Social: 30 posts activos/perfil, 3 nuevos/día audit-based, 10 vídeos activos, feed cursor 20, perfil 10 + 10.
- Chat: histórico ilimitado funcional con keyset; autosync adaptativo; read receipts `✓ Enviado` / `✓✓ Leído`.
- Contact Gate universal antes de chat nuevo.
- Cabecera/resúmenes v106 y hardening de escala 20.061.
- No llamar “Realtime/WebSocket” al chat actual si sigue siendo polling/autosync.
- Perfil Competidor reabierto en 20.062.
- Club shell muestra logo del Club/fallback neutral, nunca el logo KOMBAX.

## Escalabilidad
20.061 dejó la plataforma preparada arquitectónicamente para someterse a pruebas de alta concurrencia, pero **NO está certificada para 10.000 concurrentes** hasta ejecutar staging real.
Escalera prevista: 100 → 250 → 500 → 1.000 → 2.500 → 5.000 → 7.500 → 10.000 sesiones concurrentes.
No realizar una carga de 10K sobre producción.

## Pendientes de release / validación
1. Corregir Contact Gate UX del mensaje 10–500 caracteres.
2. Validar manualmente Competidor E2E:
   - crear perfil;
   - completar/enviar documentación;
   - revisión Admin KOMBAX;
   - verificar;
   - activar Social;
   - comprobar perfil público;
   - comprobar que consume correctamente una plaza de primeros 20.
3. Revisar los banners de Competidor en Combat Social y Club en Showcase en browser/PWA/APK.
4. Dual-account chat A↔B para read receipts y Contact Gate.
5. Probar pérdida/recuperación de red.
6. Verificar APK signed instalada sobre un dispositivo real.
7. Preparar AAB signed para Google Play una vez terminadas las validaciones de APK.
8. Resolver o aceptar explícitamente `Leaked Password Protection` en Supabase Auth.
9. Ejecutar load test únicamente en staging antes de proclamar certificación 10K.

## Flujo Google Play posterior
- APK signed: validación directa en dispositivo.
- AAB signed: artefacto para Google Play.
- Mantener package/applicationId `com.urbanwarriors.app`.
- Verificar `versionCode` antes de subir; Google Play exige incremento respecto al último AAB publicado.
- No crear un nuevo keystore para la misma app salvo decisión explícita y conocimiento de las consecuencias de firma.

## Reglas de trabajo obligatorias
- Antes de modificar: inspeccionar la fuente 20.062 real y, si toca Supabase, auditar estado live primero.
- Evidencia antes de afirmar PASS.
- No tocar producción con pruebas destructivas.
- Cambios SQL mediante migración versionada y rollback cuando correspondan.
- Mantener seguridad, ownership, multiclub y permisos como invariantes.
- No añadir infraestructura o índices “por si acaso”; justificar por medición o contrato real.
- Después de cualquier intervención:
  1. tests específicos;
  2. `npm test`;
  3. `npm run build`;
  4. paridad web=dist=Android;
  5. hash/file audit;
  6. Android preflight;
  7. secret audit;
  8. Supabase Security Advisor y Performance Advisor si se tocó backend;
  9. manual E2E relevante;
  10. ZIP + SHA-256 + informe de validación.

## Forma de acompañar al usuario en despliegues/manual
El usuario trabaja con CMD, GitHub Desktop, Netlify, Android Studio y Android real.
Cuando se esté haciendo una operación manual, dar **una sola acción/comando cada vez** y esperar resultado/foto antes de seguir.

## Siguiente intervención recomendada
Crear una intervención corta posterior a 20.062 para **Contact Gate UX Validation Hardening**:
- validación 10–500 en frontend;
- traducción humana de errores Contact Gate;
- tests de bordes;
- browser/PWA/APK;
- sin cambio de backend salvo que la auditoría demuestre una discrepancia.

## Condición de freeze
No declarar freeze final hasta que las validaciones manuales críticas anteriores estén cerradas y el AAB listo para Play haya sido generado/verificado.
