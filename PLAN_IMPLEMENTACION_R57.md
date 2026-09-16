# KOMBAX 20.107 R57 · Plan interno de implementación

1. Derivar R57 desde R56 sin modificar la baseline R56.
2. Auditar el orden de render de todas las vistas KOMBAX Social.
3. Crear acción compacta `Información de KOMBAX Social` accesible desde cabecera.
4. Crear panel secundario reutilizando:
   - identidad activa / cambio de identidad;
   - política temática/moderación;
   - normas de publicación.
5. Retirar del cuerpo principal del feed los tres bloques anteriores.
6. Retirar `identitySwitcher()` inline de las demás vistas Social y ofrecer el mismo acceso de información.
7. Conservar sin modificación:
   - anuncio fundadores;
   - botón `+ Publicar con multimedia`;
   - compositor;
   - identidad dentro del compositor;
   - aviso corto `Solo contenido de combate`;
   - feed, relaciones, mensajes, guardados, seguridad y moderación funcional.
8. Añadir estilos responsive para botón/panel, sin alterar navegación inferior.
9. Elevar release a build 20107 / R57.
10. Ejecutar regresiones Social, perfil público, Events y suite completa.
11. Ejecutar `release:build` para Netlify/PWA y certificar paridad Web=Dist=Android.
12. Ejecutar preflight Android/Google Play y registrar bloqueos externos sin falsear PASS.
13. Empaquetar ZIP completa con código, `dist`, Android, Supabase, pruebas, logs y documentación de handoff.
