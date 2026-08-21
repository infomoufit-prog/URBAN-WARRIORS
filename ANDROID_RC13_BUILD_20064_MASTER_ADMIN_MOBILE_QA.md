# Android QA · KOMBAX RC13 build 20064

## Antes de compilar

1. Descomprime la build 20064 en una carpeta local fuera de OneDrive si es posible.
2. Abre en Android Studio la carpeta `android`.
3. Usa el mismo JKS de las releases anteriores.
4. Crea localmente `android/keystore.properties` a partir de `keystore.properties.example` o reutiliza el archivo local ya validado.
5. No copies ni subas el JKS/contraseñas al ZIP ni a GitHub.
6. Confirma `versionCode 20064` y `versionName 2.0.0-rc.13`.

## Generar APK signed

Android Studio:

`Build -> Generate Signed App Bundle or APK -> APK -> app -> Existing key store -> release`

Selecciona el JKS histórico y su alias existente. No generes una clave nueva.

## Backend antes del E2E de admin

El formulario maestro 20064 requiere migración 108 live y Email OTP correctamente configurado. No pruebes el flujo final de owner hasta completar el runbook de Supabase.

## Secuencia QA móvil

### Navegación inferior

- [ ] Mi perfil / KOMBAX Social / KOMBAX Showcase / Mi Club están repartidos en cuatro espacios iguales.
- [ ] No hay hueco fantasma de quinta columna.
- [ ] Safe-area Android correcta.

### Acceso maestro

- [ ] Desde entrada KOMBAX pulsa `Entrar con mi club`.
- [ ] 7 taps sobre el símbolo KOMBAX: no ocurre nada.
- [ ] 8 taps dentro de 5 s: abre `ACCESO MAESTRO`.
- [ ] No existe botón/label visible de Administración en la app normal.
- [ ] Correo no-owner: rechazado.
- [ ] Owner + contraseña incorrecta: rechazado.
- [ ] Owner + contraseña correcta: recibe OTP.
- [ ] OTP incorrecto/caducado: rechazado.
- [ ] OTP correcto: abre Consola KOMBAX.
- [ ] Salir de la consola invalida el acceso.
- [ ] 15 min de inactividad cierra la administración.

### Consola

- [ ] Muestra todos los clubes esperados.
- [ ] Búsqueda global de perfiles funciona.
- [ ] Verificaciones pendientes funcionan.
- [ ] Moderación funciona.
- [ ] Abrir club muestra equipo/permisos.
- [ ] Mantenimiento muestra build/contexto/trazas.

### Mensajes técnicos

Provoca de forma controlada errores de red/permisos en QA y comprueba:

- [ ] no aparece `RLS`;
- [ ] no aparece `RPC`;
- [ ] no aparece `Supabase`/`PostgreSQL` como error al usuario;
- [ ] no aparecen nombres `app_*`;
- [ ] no aparecen tablas/constraints/schema;
- [ ] el usuario recibe mensajes humanos;
- [ ] la Consola/Mantenimiento conserva trazas útiles.

### Regresión 20063

- [ ] Comentarios inline.
- [ ] Mi red.
- [ ] Chat Social: X conserva conversación.
- [ ] Eliminar conversación funciona.
- [ ] Badge Mensajes.
- [ ] Filtros Social / Showcase.
- [ ] Chat Showcase por producto tras activar 107.

## Criterio de aprobación

No desplegar 20064 en Netlify ni generar AAB de Google Play hasta completar esta matriz sin bloqueantes.
