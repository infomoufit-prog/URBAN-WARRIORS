# KOMBAX RC13 · build 20050 · ACCOUNT SECURITY

- Añade cambio de contraseña desde una sesión iniciada.
- Ubicación: Mi perfil / Mi perfil personal → Seguridad y acceso.
- Gestor y Coordinación también disponen de acceso directo desde Perfil del Club.
- Cuenta KOMBAX global dispone de Cambiar contraseña junto al cierre de sesión.
- El flujo exige contraseña actual, nueva contraseña y confirmación.
- Reautentica explícitamente contra Supabase Auth antes de actualizar.
- Comprueba que la identidad reautenticada coincide con la sesión de aplicación.
- Mínimo local: 8 caracteres; Supabase conserva la autoridad sobre requisitos adicionales.
- Tras un cambio correcto se revoca la sesión y se exige iniciar sesión con la nueva contraseña.
- No añade tablas, RPC, migraciones ni claves privilegiadas.
