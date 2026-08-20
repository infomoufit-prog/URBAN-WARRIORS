# STATUS · KOMBAX 20.058 · NAVIGATION + HEADER ACTIVITY · INTERVENCIÓN 2

Candidata actual de validación: **build 20058**.

## Implementado en 20.058 hasta esta intervención

- Navegación global prioritaria: `Mi perfil`, `KOMBAX Social`, `KOMBAX Showcase`.
- `Mi Club` como acordeón de accesos operativos gobernados por rol.
- Dirección/Coordinación: `Mi perfil` personal separado de `Perfil del club`.
- Navegación móvil simplificada a Mi perfil / Social / Showcase / Mi Club.
- Botón de menú móvil con mayor affordance y área táctil.
- `Notificaciones del Club` fuera del menú lateral y mantenidas en cabecera.
- Refresh token inválido: limpieza de sesión + mensaje humano.
- Pérdida temporal de red durante restauración: conserva sesión local y reintenta al recuperar conectividad.
- Sin cambios de esquema Supabase.

## Evidencia automática

- `npm test`: **PASS**.
- `npm run build`: **PASS**.
- `web = dist = Android`: **65 / 65 / 65**, listas iguales y `0` diferencias de hash.
- Android `versionCode`: **20058**.
- Android preflight: **4/5**, solo firma local pendiente.
- No se incluyen JKS, keystore, P12/PFX ni claves privadas en el paquete.

## Estado de release

**CANDIDATA DE VALIDACIÓN MANUAL · NO FREEZE.**

La 20.058 incorpora ya separación real de cabecera **Notificaciones KOMBAX / Notificaciones del Club / Mensajes**. La actividad KOMBAX del header contabiliza solicitudes de red/contacto que requieren decisión; Mensajes contabiliza no leídos de chats aceptados; Club conserva el centro operativo existente. La siguiente intervención de 20.058 cerrará validación visual/manual y después se continuará con 20.059 para Mi red KOMBAX, Contact Gate, chat realtime, Showcase messaging y comentarios inline.
