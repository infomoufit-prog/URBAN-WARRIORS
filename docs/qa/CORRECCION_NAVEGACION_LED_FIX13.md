# FIX13 · Tarjetas premium compartidas con Club

Esta revisión acumula FIX12 y corrige la diferencia visual señalada con la captura de Club. El informe AUDITORIA_ACUMULATIVA_FIX12.md sigue describiendo los cambios funcionales; este documento sustituye su descripción de la navegación visual.

Los espacios gestionados reutilizan las clases de las tarjetas y acordeones de Club y sus mismas reglas CSS de color, bordes, iconos, brillo, estados abiertos y foco. Social: rosa; Events: cian; Showcase: dorado; Recursos: azul; espacio propio: rojo. Las reglas existentes de Club siguen aplicándose al mismo componente para todos sus roles, sin crear variantes menos cuidadas de equipo.

Se conserva la cabecera con el nombre de la identidad. Las herramientas específicas quedan dentro del acordeón de Mi Marca, Mi Federación, Mi actividad, Mi contenido o el espacio correspondiente. Mi perfil, Mi Espacio y cerrar sesión permanecen disponibles. Las tarjetas solo aparecen cuando están presentes los módulos correspondientes; abrir un módulo sigue pasando por los controles anteriores de capacidades y verificación. Esta revisión no activa servicios ni cambia permisos.

Pruebas realizadas:

- 40 comprobaciones Chrome móvil: familias, finanzas, colores de tarjetas en Marca/Federación/Profesional/Media y agrupación de herramientas.
- 64 comprobaciones del componente Club con menús de prueba según permisos en dirección, coordinación, secretaría, economía, comunicación, monitor, familia y alumno. No son sesiones autenticadas de ocho cuentas reales ni una nueva auditoría del backend de esos roles.
- 21 comprobaciones de navegación móvil/escritorio, foco, cierre y contrato de cerrar sesión.
- 91 suites acumulativas aprobadas; tres P2 históricos de traducción, cero fallos nuevos. No se declara npm test estricto totalmente limpio.
- Inspección visual de BARRA_PREMIUM_IDENTIDAD_FIX13.png.
- Compilación y comprobación de recursos web/dist/Android. No se ha compilado APK/AAB ni desplegado Netlify.

FIX13 aplica además la activación financiera autorizada: véase CUOTAS_Y_PAGOS_MULTIPLES_FIX13.md. Esta corrección requiere desplegar el frontend actualizado para la webapp; la APK anterior necesita una compilación nueva para incorporar sus recursos. El código base permanece 20178 y no es reutilizable como nuevo versionCode en Google Play.

Entrega acumulativa en cuatro partes, reunificador CMD y validación SHA-256/CRC. No mezclar partes FIX12 y FIX13.
