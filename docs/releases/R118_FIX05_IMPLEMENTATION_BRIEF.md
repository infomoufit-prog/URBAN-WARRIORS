# KOMBAX 20177 R118 FIX05 — criterios de implementación

Objetivo: entregar una revisión acumulativa, en cuatro partes reunificables, con acceso general al inicio de cuatro tarjetas, Mi Espacio con navegación lateral y un perfil personal con capacidades verificables. Mantener FIX01–04, permisos privados, documentos y servicios existentes.

Fases:
1. Inventariar código y contratos de servidor. Respaldar los archivos modificados y mantener los datos privados fuera del paquete.
2. Cambiar destinos de sesión/registro y restauración al inicio, preservando invitaciones, recuperación, requisitos legales y alta piloto.
3. Integrar navegación lateral reutilizable en Mi Espacio y módulos globales. Eliminar Cambiar espacio solo con alternativa accesible. Separar cuenta, perfil personal, facetas y organizaciones.
4. Revisar identidad social compartida, permisos del practicante, prueba expresa de 30 días y límites gratuitos de organizaciones. Corregir el servidor cuando haga falta, con pruebas SQL aisladas antes de aplicar.
5. Añadir regresiones de estados y navegación; ejecutar todas las verificaciones del proyecto y pruebas de navegador en escritorio y móvil. Revisar errores, permisos, coherencia y copias web/dist/Android.
6. Comprobar herramientas Android y ejecutar la compilación disponible. No afirmar APK/AAB firmadas ni despliegue remoto si no se han obtenido.
7. Crear ZIP acumulativo sin claves ni dependencias, dividirlo en cuatro partes, reunificarlo y verificar CRC, SHA256 y archivos críticos. Entregar instrucciones y resultados con limitaciones concretas.

Criterios: cuenta gratuita no crea identidad ni concede publicación; practicante publica solo con membresía confirmada; agregar capacidades no duplica el perfil social; organizaciones separadas; 30 días desde activación explícita, sin cobro automático; piloto sigue independiente. No push ni deploy automático. Cada fallo se resuelve o queda identificado explícitamente, sin certificación ficticia.

Revisión propia: leer este documento dos veces antes de editar código y contrastar los resultados contra cada fase al entregar.
