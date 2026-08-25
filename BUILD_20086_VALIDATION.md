# KOMBAX RC13 build 20086 · Validación final

## Resultado
- `npm run test:20086`: PASS
- `npm test`: PASS
- `npm run release:build`: PASS
- Legal release gate: PASS
- `web = dist = android/app/src/main/assets/www`: 79/79/79 archivos
- Android preflight: 4/5; único pendiente intencional = firma local `keystore.properties`/JKS
- Escaneo de secretos: sin `.env`, JKS, keystore, PEM/P12 ni claves privadas empaquetadas

## Funcionalidad 20.086
- Histograma mensual agrupado, animado y táctil.
- Donut de antigüedad de deuda animado y táctil.
- Barras interactivas por categoría, grupo y disciplina.
- KPIs con drill-down y filtros cruzados.
- Selección persistente y accesible.
- `prefers-reduced-motion` respetado.
- Visor profesional de recibo restaurado para el club.
- Informes PDF con CORS/OPTIONS, branding, KPIs, histograma, antigüedad y tabla.

## Backend sincronizado
- Supabase `finance-report`: v3 ACTIVE.
- Supabase `health`: v11 ACTIVE, build 20086.
- Migraciones financieras/social/security previas preservadas.
- Gates de recurrencia/piloto no abiertos por esta build.

## Flujo recomendado
1. Subir este FULL con GitHub Desktop.
2. Desplegar Netlify/PWA.
3. Validar Finanzas > Resumen, Recibos e Informes en móvil.
4. Validar KOMBAX Social/chat y cambio de contexto.
5. Solo después generar APK/AAB signed usando el keystore local del usuario.
