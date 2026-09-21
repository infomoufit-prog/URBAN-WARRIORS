# QA Handoff · KOMBAX 20.101 R49

## Gates automatizados verificados antes de empaquetado
- R40 Social/Events visibility: 74/74 PASS.
- R44 Events flow stability: 25/25 PASS.
- R47 Social visibility/media: 28/28 PASS.
- R48 Events Premium: 28/28 PASS.
- R49 Social + Events Final Polish: 29/29 PASS.
- `npm test`: EXIT 0.
- `npm run build`: PASS, 189 archivos sincronizados.
- Paridad: web 189 / dist 189 / Android assets 189; 0 faltantes, 0 extras, 0 diferencias SHA.
- Hash agregado runtime previo al empaquetado: `66737acfd4603a850b534b1adcc03c371ed80659c3e3be74f86192be1b39a22d`.
- Android preflight: 4/5; único gate no satisfecho = firma local (`android/keystore.properties`).

## QA manual recomendado antes de producción
1. Dos identidades autenticadas: comprobar que Like y Me interesa son independientes.
2. Desde autor: confirmar que solo se muestran métricas públicas de likes/comentarios y no preferencias privadas.
3. Marcar Me interesa, No me interesa y Sin preferencia; recargar y comprobar persistencia.
4. Reportar una publicación con “Contenido fuera de temática” y comprobar entrada en moderación, sin borrado automático.
5. Abrir eventos Urban Warriors ya existentes y comprobar que heredan animación de póster y visor fullscreen.
6. Probar Main, Co-Main, cartelera sin fotos, cartelera con fotos y cartel completo de Fight Card en móvil real.
7. Probar `prefers-reduced-motion` o equivalente de accesibilidad del dispositivo.
