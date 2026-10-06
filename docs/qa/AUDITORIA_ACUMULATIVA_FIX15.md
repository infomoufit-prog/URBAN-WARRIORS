# Auditoría acumulativa FIX15

6 de octubre de 2026. Base: FIX14 completo. Cambio de alcance visual: únicamente reglas CSS de las dos portadas y renovación de la caché estática.

## Causa y corrección

La imagen gateway-kombax-community.webp se ampliaba con cover y transformaciones de escala; el contenedor y las máscaras/solapamiento con el texto ocultaban partes del conjunto. Se conserva el original 1448×1086 y se muestra a proporción 4:3 con contain, sin transformaciones ni máscaras opacas. Se conserva la composición integrada del panel original y sus efectos premium. El encuadre ocupa una zona independiente del texto visible, con separación del borde; en móvil se reserva espacio vertical para evitar solapamiento. No se modifica el resto de portadas Social/Showcase/Events.

## Pruebas de esta revisión

- 10 casos reales de renderizado en Chrome local: onboarding e Inicio a 360, 390, 844, 1024 y 1440 píxeles. Se comprueban proporción original, contain, ausencia de ampliación, máscaras, solapamiento y desbordamiento horizontal.
- Capturas revisadas visualmente en móvil y escritorio, en ambas pantallas: los siete peleadores y las cabezas aparecen completos.
- Regresión de navegador FIX14: 40 casos aprobados.
- Regresión acumulativa de contexto y familias: 42 casos aprobados.
- Compilación: 639 archivos idénticos web/dist/Android. Compatibilidad Linux: 895 importaciones locales en 373 archivos JavaScript comprobadas.

Las pruebas de navegador usan sesiones y transportes simulados; no escriben cuentas reales. La ejecución completa de 96 suites corresponde a la base FIX14, no se afirma una nueva ejecución de esas 96 suites en FIX15. Su evidencia y tres P2 históricos de traducción siguen incluidos; no se cambia la línea base ni se oculta esa deuda.

## Entrega y límites

FIX14 intacto; FIX15 acumulativo en cuatro fragmentos, reunificador Windows y SHA-256. Integridad CRC y reunificador verificados antes de entregar. Sin cambios Supabase, push GitHub, despliegue Netlify, publicación Play, cobros ni APK/AAB compilada. El ajuste estará disponible en la web cuando se despliegue este frontend.
