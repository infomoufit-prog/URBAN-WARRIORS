# Changelog · KOMBAX RC13 build 20064

## MASTER ADMIN + FRONTEND CLEANUP

- Nueva puerta de administración móvil: 8 taps sobre el símbolo KOMBAX en el directorio de clubes, dentro de 5 segundos.
- Nueva ruta PWA privada `/admin`.
- Administración global retirada del menú, perfil y configuración ordinarios.
- Flujo maestro: contraseña + Email OTP + challenge backend + sesión admin efímera.
- Consola global separada del shell de club.
- Mantenimiento técnico restringido a la consola maestra.
- Migración 108 preparada, no aplicada live al cerrar el paquete.
- Sanitización transversal de errores técnicos en frontend.
- Limpieza de etiquetas internas en gateway y perfil Profesional/Representante.
- Barra inferior móvil corregida para distribuir dinámicamente el número real de accesos; en la configuración actual son cuatro columnas equilibradas.
- Test automático específico 20064 y adaptación de regresiones históricas afectadas por el nuevo requisito.
- Build final: web = dist = Android, 67 archivos, 0 diferencias de hash.
- Android preflight: 4/5; firma release pendiente de credenciales locales JKS excluidas intencionadamente.
- Netlify no desplegado; la build web de referencia permanece 20062 hasta freeze.
