# KOMBAX — Continuidad tras la entrega final PWA universal R270

El usuario ha solicitado **no abrir más fases**. El objetivo es publicar las últimas mejoras. No iniciar nuevas funciones ni reiterar fases cerradas.

1. Partir del **ZIP final acumulativo R270** y comprobar SHA-256.
2. Instalar dependencias con `npm ci` (Node 22) en entorno conectado y ejecutar `npm run release:build`; documentar cualquier primer bloqueo antes del despliegue.
3. Usar únicamente `dist/` para despliegue manual de la web o la configuración `netlify.toml` en CI. El propietario hace el despliegue; no hacer push ni deploy sin permiso.
4. Comprobar iconos, manifest, SW/cache y opción Instalar KOMBAX para todos los roles; Android Chrome muestra prompt cuando el navegador lo permite, iOS Safari muestra pasos Añadir a pantalla de inicio.
5. Meta/Instagram y Stripe/VIP quedan pendientes de prueba real consentida con credenciales y cuentas autorizadas. No declararlas certificadas hasta completar E2E.
6. Mantener historial financiero, licencias, permisos y pedidos existentes; ninguna operación destructiva sin autorización explícita.
