# KOMBAX 20178 · FIX11 acumulativo

Incluye FIX10 y la auditoría de altas de cuenta, club piloto, familias, equipos, perfiles y vendedor. Las tres correcciones nuevas de Supabase están aplicadas al proyecto poggsobhtutbuagjiydc. Frontend preparado, sin push ni despliegue automático.

Consulta docs/qa/AUDITORIA_ALTAS_FIX11.md para causa del fallo, correcciones, cobertura, pruebas, límites y correspondencia de migraciones locales con las versiones aplicadas. No repetir esas migraciones en el mismo proyecto sin revisar el historial.

QA: 59 comprobaciones nuevas de base aislada; 73 comprobaciones de navegador móvil; 83 suites acumulativas correctas y tres P2 históricos de traducción. No se declara la suite estricta totalmente limpia. No se han creado cuentas o clubes reales para probar ni consumido plazas piloto.

Coloca las cuatro partes KOMBAX_20178_R118_FIX11.zip.001 a .004 y UNIR_KOMBAX_20178_FIX11.cmd juntos. Ejecuta el CMD; verifica el resultado y extrae el ZIP. No mezcles partes de versiones anteriores. Conserva .git, credenciales y firma local al trasladar el código.

No se incluyen claves, dependencias instaladas ni APK/AAB compiladas. El código Android conserva 20178: antes de subir una AAB debe llevar un versionCode nuevo superior al máximo usado en Google Play y la misma firma de aplicación. La equivalencia de recursos web/Android no sustituye la compilación nativa y prueba en dispositivo.

Las nuevas pantallas requieren actualizar web/APK. El fallo específico del alta piloto corregido en Supabase permite volver a intentar el alta con la aplicación actual. No se han probado envíos reales de correo ni cobros Stripe en esta auditoría.
