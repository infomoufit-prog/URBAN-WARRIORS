# KOMBAX · continuidad desde RC13 build 20076

Fuente candidata: build 20076 BANNER POSITIONING.

Estado relevante:
- Tests y build PASS; 73 archivos web=dist=Android.
- Supabase migraciones 119–132 aplicadas; 131/132 corresponden al posicionamiento persistente de banners.
- Banner: arrastre ratón/táctil, sliders X/Y, Centrar, guardado persistente. No recorta el fichero original.
- Perfiles canónicos Miembro/Club/Marca/Federación/Competidor soportan punto focal; vista pública separada del Club también.
- Health Supabase v4 responde HTTP 200 / build 20076 / DB OK.
- Invitaciones equipo y alumnos por email continúan implementadas desde 20074/20075.
- Android preflight 4/5: pendiente firma local.
- Email/Auth E2E real sigue pendiente hasta activar/validar las plantillas alojadas y recibir los correos.
- Gate legal sigue pendiente de los datos legales/contactos finales.
- Backup+restore real aislado sigue pendiente de credenciales/destino temporal.
- GitHub y Netlify NO se han tocado; mantener así hasta autorización explícita.

Siguiente secuencia recomendada: E2E emails -> legal/contactos -> backup/restore aislado -> QA dispositivo Android -> GitHub privado -> Netlify/kombax.es -> APK/AAB -> Google Play.
