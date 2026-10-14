# Riesgos, límites de aceptación y requisitos antes de desplegar

1. La navegación usa módulos `workspace`/capacidades; no equivale a autorización backend. Validar con perfiles verificados, sin verificar, con suscripciones diferentes y suspendidos.
2. `profile_team` reutiliza el control existente; comprobar permisos negativos de federación, competidor y profesional.
3. Los estilos nuevos necesitan invalidación del cache de PWA, y el versionado R118/build 20178 debe reconciliarse con R120 FIX22 antes del despliegue.
4. La navegación federativa expone secciones, pero funcionalidades premium faltantes se desarrollarán en la fase siguiente.
5. Compatibilidad visual real en Android, PWA y escritorio no certificada.
6. Los paquetes acumulativos grandes necesitan reunificación y SHA-256 antes de usarse.
7. Nunca asumir que los módulos visualmente visibles conceden capacidad, derecho de acceso a datos de menores o finanzas de otros clubes.
