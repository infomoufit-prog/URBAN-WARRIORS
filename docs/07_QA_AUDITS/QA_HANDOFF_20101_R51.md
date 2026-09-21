# QA HANDOFF — KOMBAX 20.101 R51

## Automatizado
- R51 focal: 54/54 PASS.
- `npm test`: EXIT 0.
- Build: 190 archivos, web = dist = Android.
- Paridad: 0 faltantes, 0 extras, 0 diferencias SHA.
- Runtime aggregate SHA-256: `419336c8db28aee671c2b4025bf1aea4945e511a3aefca78f5417ce18b5ec071`.
- Android preflight: 4/5; falta únicamente `android/keystore.properties` local.

## QA manual recomendada
1. KOMBAX Social: subir MP4 vertical/horizontal/cuadrado y comprobar portada automática.
2. Elegir fotograma y verificar que el MP4 original no cambia.
3. Subir portada propia y sustituirla.
4. Cambiar álbum entre Completo / Equilibrado / Rellenar en foto y vídeo.
5. Abrir fullscreen y verificar original completo.
6. Repetir como Club/perfil directo.
7. KOMBAX Events: repetir portada y encuadre en álbum autenticado y evento público.

Clasificación: candidata QA; no producción firmada hasta QA manual, cierre global de Advisors y firma Android local.
