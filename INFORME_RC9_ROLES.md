# Informe RC9 · Gestor de la app y Coordinación

RC9 introduce una separación clara entre el propietario técnico/administrativo de la aplicación y la gestión cotidiana del club.

**Gestor de la app** sustituye visualmente a “Dirección” como nombre del rol máximo. Conserva la clave interna `direccion` por compatibilidad y mantiene soporte, invitaciones, diagnóstico, certificación E2E y borrados totales.

**Coordinación** es un nuevo nivel visible de gestión operativa. Su invitación es única; al aceptarla, el backend activa de forma transaccional los permisos operativos de Secretaría, Economía y Comunicación y los marca como una sola identidad de Coordinación. No recibe nunca el rol interno `direccion`.

El panel de Coordinación ofrece navegación global de gestión, pero Configuración no muestra Herramientas técnicas y los módulos no muestran botones `Eliminar todo`.

No se modifican el modelo de alumnos, archivo documental, reservas de sesión, material, publicaciones, notificaciones, pagos ni Storage.
