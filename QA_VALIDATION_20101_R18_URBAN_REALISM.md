# QA · KOMBAX 20.101 R18 · Urban Warriors Realism

## Backend real verificado
- Participantes: 10
- URLs de foto distintas: 10
- Combates: 5
- Main Event: exactamente 1
- Seed ejecutado dos veces para validar idempotencia: PASS
- Privilegios seed: anon=false, authenticated=true, service_role=true

## Frontend / Android
- Test dedicado `test-kombax-20101-urban-realism-r18.mjs`: PASS
- 10 retratos WEBP únicos: PASS
- Fight Card y participantes resuelven el banco realista: PASS
- Álbum demo contiene las 10 fotografías: PASS
- Lightbox admite media local empaquetada: PASS
- Gestor de álbum incluye las 10 fotografías: PASS
- Assets presentes en web/dist/Android: PASS

## Regresión
- `npm run build`: PASS
- Suite completa histórica: PASS
- Resultado: `OK build 162 archivos · web = dist = Android`

## Android release preflight
- 4/5 PASS
- Único pendiente: `android/keystore.properties` local para firma.
- No se ha generado una APK Signed en este cierre.

## Advisors Supabase
Se ejecutaron advisors de seguridad y rendimiento. Persisten avisos globales/históricos del proyecto; no se declara la base completa como limpia. No se detectó un bloqueo de rendimiento específico introducido por esta intervención.

## Criterio de aceptación pendiente de dispositivo
La build está validada en código/backend, pero la validación visual final requiere instalar una APK generada desde esta R18 o desplegar esta R18 en PWA y comprobar:
1. 5 combates visibles.
2. 10 caras diferentes, sin repeticiones.
3. Solo un `MAIN EVENT`.
4. Álbum con 10 retratos.
5. Ningún icono de imagen rota.
