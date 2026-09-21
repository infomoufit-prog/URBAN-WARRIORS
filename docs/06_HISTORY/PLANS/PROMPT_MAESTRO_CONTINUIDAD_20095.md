# PROMPT MAESTRO DE CONTINUIDAD · KOMBAX 20.095

Trabaja exclusivamente sobre **KOMBAX RC13 build 20.095 · Integration / Hardening Final Candidate**. No rehagas módulos ni mezcles archivos de builds anteriores.

## Estado de partida

- 20.095: `npm test` PASS, `npm run build` PASS, legal gate PASS.
- web/dist/Android: 101 archivos idénticos.
- Android versionCode 20095; `com.urbanwarriors.app`.
- Deep-links públicos `event`/`fight` ya corregidos.
- KOMBAX Eventos público sigue separado de `Mi Club > Eventos`.
- Storage Eventos privado; `event-media-url` v1 ACTIVE; resolver interno service-role-only.
- Production `health` permanece build 20094 hasta desplegar el frontend 20095.
- Espectador sigue DESHABILITADO.
- No hay JKS/contraseñas dentro del ZIP.

## Próxima misión

Realizar **validación real de despliegue y Android**, no desarrollar una nueva gran feature:

1. verificar integridad del ZIP;
2. ejecutar QA/build local en el PC autorizado;
3. preparar/subir GitHub Desktop cuando el usuario lo indique;
4. validar Netlify/kombax.es tras el deploy;
5. probar deep-links Evento/Fight en navegador y Android;
6. después de confirmar frontend 20095 live, actualizar `health` a 20095 y verificar GET/HEAD;
7. configurar firma local con el JKS existente y obtener Android preflight 5/5;
8. generar APK release signed y AAB desde exactamente la misma fuente;
9. validar actualización física, push, Social, Showcase, Eventos, Mi Club y Finanzas;
10. para App Links verificados, usar la huella real de Google Play App Signing y Digital Asset Links; no asumir la huella de la upload key.

## Límites

- No activar Espectador sin gate específico de edad/privacidad.
- No abrir Storage de Eventos.
- No permitir que `event.fight.save` escriba resultados.
- No mezclar eventos privados del club con KOMBAX Eventos.
- No crear una nueva keystore.
- No afirmar que Netlify/Play está validado antes de ejecutar las pruebas reales.
