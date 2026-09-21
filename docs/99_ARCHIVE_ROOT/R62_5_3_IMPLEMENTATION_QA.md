# R62.5.3 — Implementation & QA

## Resultado
**LOCAL BUILD: PASS**  
**R62.5.3 FOCUSED TEST: PASS**  
**SUPABASE MIGRATION: APPLIED**  
**ANON EXPOSURE NEW RPCs: NONE**  
**WEB = DIST = ANDROID: PASS**

## Casos cubiertos
1. La configuración del ticket pertenece al evento y se guarda server-side.
2. QR, código, estado y legal KOMBAX no son configurables por el organizador.
3. Solo se aceptan paletas visuales KOMBAX predefinidas.
4. Máximo 6 logos y solo de entidades vinculadas/aceptadas del mismo evento.
5. Límites server-side: puertas 80, acceso 120, instrucciones 250 caracteres.
6. `anon` no puede ejecutar las RPC R62.5.3.
7. El wallet del comprador recibe diseño e información operativa sin cambiar el token del ticket.
8. Digital e imprimible usan el mismo QR/ticket.
9. La impresión utiliza la función del navegador (`Imprimir / Guardar PDF`) y no emite tickets nuevos.
10. Regresión R61, R62.4, R62.5 y R62.5.2 en verde.

## Build
`npm run build` completado correctamente. Resultado del empaquetador: `OK build 197 archivos · web = dist = Android`.

## Auditoría Supabase
- Security advisor: no se introdujo exposición `anon` en R62.5.3. Continúan avisos históricos del proyecto, incluido Leaked Password Protection desactivado.
- Performance advisor: no detecta FK/tabla nueva de R62.5.3 que requiera índice. Continúa deuda histórica global ajena a este cambio.

## Pendiente interactivo de piloto
- compra Stripe TEST autenticada y retorno a `Mis entradas`;
- comprobación visual real del ticket en móvil/PWA/Android;
- impresión/Guardar PDF en navegador real;
- lectura del QR impreso y digital contra el mismo ticket;
- reembolso Stripe TEST y posterior invalidación del ticket.

Estos puntos no deben marcarse como E2E PASS hasta ejecutarse con sesión/Stripe TEST reales.
