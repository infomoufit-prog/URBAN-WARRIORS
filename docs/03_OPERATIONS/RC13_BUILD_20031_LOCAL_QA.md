# RC13 build 20031 · QA local

Estado: candidato de validación local, no desplegado.

Validaciones ejecutadas:
- `npm test`: PASS.
- regresión `test-kombax-20031-social-profile-avatar.mjs`: PASS.
- `npm run build`: PASS.
- `web = dist = Android`: PASS (71 archivos).
- HTTP smoke local `/`: 200.
- HTTP smoke local `/js/app.js?v=20031`: 200.
- `config.js`: build 20031.
- Supabase 058 aplicada: SUCCESS.
- Verificación Supabase: 8/8 TRUE para policies, helpers, trigger, feed/directorio/comentarios y release contract.

Cambios funcionales a validar manualmente:
1. Cambiar foto en Mi perfil y mantener marcada “Usar también como foto pública en KOMBAX Social”.
2. Confirmar avatar en KOMBAX Social, publicaciones antiguas y directorio de perfiles.
3. Tocar nombre/avatar de una publicación y comprobar apertura del perfil público correcto.
4. Comprobar perfil público: cabecera, bio, club de origen, álbum, actividad, relaciones y contacto cuando proceda.

No ejecutar deploy, APK ni AAB hasta cerrar QA funcional.
