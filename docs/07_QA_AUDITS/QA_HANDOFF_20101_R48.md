# QA HANDOFF · KOMBAX 20.101 R48

## Propósito
Validar en dispositivo real la experiencia premium de Combat Events sin reabrir arquitectura ni introducir cambios funcionales no relacionados.

## Recorrido manual obligatorio
1. Entrar con identidad real autorizada de un club organizador.
2. Abrir un evento existente y confirmar hero, datos, Main Event y navegación estable.
3. Crear/editar un Co-Main Event y comprobar que solo se presenta como segundo foco, no como Main.
4. Revisar una cartelera con varios combates y verificar orden, categoría, peso, hora y legibilidad.
5. Subir un cartel gráfico completo JPG/PNG/WEBP desde `Gestionar Fight Card`.
6. Comprobar que aparece en `CARTELERA OFICIAL` y simultáneamente en el álbum.
7. Tocar el cartel y abrirlo en visor fullscreen.
8. Sustituirlo por otro: el anterior no debe desaparecer hasta que el nuevo upload termine correctamente.
9. Retirar el cartel y comprobar que Fight Card estructurada y álbum siguen coherentes.
10. Probar un combate sin retratos individuales y confirmar fallback visual.
11. Editar/guardar/reabrir varias veces para confirmar que se conserva la estabilidad R44.
12. Repetir en móvil vertical, móvil horizontal y desktop/tablet.

## Gates automatizados ya superados
- `npm run test:20101:r48`: 28/28 PASS.
- `npm test`: EXIT 0.
- `npm run build`: PASS.
- Paridad runtime: PASS 189/189/189.
- Secret scan: PASS, 0 hallazgos.
- Android preflight: 4/5; pendiente únicamente firma local.

## Criterio de aceptación manual
No debe haber clics muertos, doble navegación, cortes al guardar, desincronización de Main/Co-Main, poster fantasma, pérdida del cartel previo ante upload fallido ni contenido oculto por la barra inferior móvil.

## HOLD
Hasta completar este recorrido y la revisión de seguridad global, R48 no debe clasificarse como release firmada ni como apta para carga de datos personales reales del piloto.
