# QA Handoff — KOMBAX 20.106 R56

## Objetivo
Candidata de congelación para validación y estabilización QA del perfil público/propio, derivada de R55.

## Gates automatizados
- R56 focal: 25/25 PASS.
- Suite completa: EXIT 0.
- Build: 191 web = 191 dist = 191 Android.
- Paridad: 0 missing, 0 extra, 0 SHA diff.
- R55 Events: 26/26 PASS + load-budget 5/5 PASS.
- R54 Events: 14/14 PASS.
- R53: 21/21 PASS.
- R51 multimedia/portadas: 54/54 PASS.

## Android / Google Play
- applicationId: `com.urbanwarriors.app`
- versionCode: `20106`
- versionName: `2.0.0-rc.13-r56-qa-freeze`
- Firebase: presente.
- Preflight release: 4/5; falta firma local `android/keystore.properties`.
- APK debug: fuente/assets preparados; compilación física no completada en este entorno porque Gradle no puede resolver `services.gradle.org`.
- AAB Google Play: pendiente de firma local y compilación.
- No se ha publicado en Google Play.

## QA manual prioritaria
1. Mi perfil Miembro: tras la navegación global, el banner debe ser el primer contenido; botón Gestionar visible y accesible.
2. Confirmar que todas las acciones anteriores siguen disponibles dentro de Gestionar, incluida Privacidad y condiciones.
3. Perfil público ajeno: Mi red / Contactar / Denunciar / Compartir siguen presentes.
4. Álbum con <=5 elementos: no aparece Ver álbum completo.
5. Álbum con >5: solo 5 en ficha; botón abre el álbum completo y filtros funcionan.
6. Verificar portada de vídeos tanto en resumen como en álbum completo.
7. Social: 5 publicaciones + anteriores.
8. Showcase: 4 productos + ver todo.
9. Repetir en Club, Federación, Marca, Competidor y demás identidades disponibles.
10. Android físico: repetir 1-9 tras compilar APK 20106.

## Criterio de congelación
No declarar estable final hasta completar QA autenticada, APK físico y AAB release firmado. R56 sí puede utilizarse como baseline de estabilización QA.
