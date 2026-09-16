# KOMBAX 20.110 R60 · QA Matrix — Pilot Final Profile / Chat / Network / Media

## Resultado

**QA de código y regresión: PASS.**

| Control | Resultado |
|---|---:|
| `npm test` suite completa | PASS |
| R60 Pilot Final Profile/Chat Polish | 24/24 |
| R60 Pilot Final Assist + Conversations | 28/28 |
| R60 Migrations / Guide / History | 32/32 |
| Release legal gate | PASS |
| Build sync | `web = dist = Android` · 197 archivos |
| Android identity | PASS · `com.urbanwarriors.app` |
| Android versionCode | PASS · `20110` |
| Android embedded web assets | PASS |
| Firebase configuration | PASS |
| Firma local | PENDIENTE localmente |

## Cobertura específica del hotfix final

1. Hero Social con headroom en portrait.
2. Peleador Social conserva focal a la derecha.
3. Chat Assist/Migrations usa avatar, no ilustración completa.
4. Action rail de perfil público no desborda viewport.
5. `Añadir a mi red` usa fila responsive completa en móvil.
6. Mi Red usa perfiles de red dedicados.
7. Mi Red elimina selector nativo gris `Perfil` cuando no hace falta.
8. Identidad de red solo aparece si existen varias identidades válidas.
9. Miembro verificado de club puede gestionar red sin `social.publish`.
10. Lectura de relaciones usa autorización específica de actor de red.
11. Publicaciones de perfil retornan metadata multimedia.
12. Repositorio enriquece URL de media.
13. Actividad de perfil pinta foto/vídeo.
14. Media de actividad abre visor inmersivo.
15. Moderación Showcase es secundaria/icon-only.
16. No se repite `Denunciar` como texto visible en cada mensaje.
17. History delete acepta `management` como Assist.
18. Borrado mantiene Soporte separado.
19. Allowance consumido se conserva tras borrar historial.
20. Identidades QA/DEMO públicas quedan ocultas para piloto.
21. Helper interno de actor de red no queda expuesto como RPC autónoma.

## Android / dispositivo real

El preflight de proyecto queda 4/5 únicamente por la firma local. El paquete no contiene `android/keystore.properties`, `.jks` ni `.keystore`.

Antes de producción general debe ejecutarse QA física autenticada como mínimo en:

- Android móvil portrait y landscape.
- PWA móvil.
- Tablet portrait y landscape.
- Flujo Social: directorio → perfil → Mi Red → Mensajes.
- Showcase: producto → Me interesa → conversación.
- Assist y Migrations: conversación, límites y borrado.
- Soporte KOMBAX: chat guiado + ruta de revisión humana.
- Actividad de perfil con vídeo/foto y fullscreen.
- Events: listado → detalle → vuelta, conservando scroll y sin recarga destructiva.
