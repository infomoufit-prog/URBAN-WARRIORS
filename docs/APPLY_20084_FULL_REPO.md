# KOMBAX 20.084 FULL · uso del candidato completo

Este paquete **ya está integrado** sobre el último candidato desplegado 20.077. No es necesario copiar ningún patch encima.

## Flujo recomendado

1. Descomprimir el ZIP completo en una carpeta nueva.
2. Ejecutar `npm test`.
3. Ejecutar `npm run release:build`.
4. Revisar GitHub Desktop y publicar los cambios desde esta carpeta/proyecto según tu flujo habitual.
5. Aplicar en Supabase las migraciones nuevas **143 → 149**, en orden, en el entorno elegido para QA/piloto.
6. Desplegar `finance-recurring` y `finance-report` manteniendo los gates cerrados.
7. Hacer el deploy web/Netlify.
8. Abrir `android/` en Android Studio.
9. Configurar localmente la firma mediante `android/keystore.properties` o variables `UW_*`; nunca subir las credenciales.
10. Generar APK/AAB release signed con `versionCode 20084`.
11. Subir AAB a Google Play testing.
12. Ejecutar QA hostil de dos clubes, permisos, Storage, chats, Owner/Soporte y Finanzas.
13. Activar Leaked Password Protection y verificar MFA TOTP del Owner antes de declarar `PILOT SECURITY READY`.

## Seguridad

- El ZIP no contiene JKS, keystore real, passwords de firma ni `service_role` de Supabase.
- `pilot_security_enabled`, recurrencias financieras y Finance live permanecen cerrados por defecto.
- El modo Owner/Soporte exige trazabilidad y, cuando se habilita enforcement, AAL2.
