# Roadmap controlado · Urban Warriors

## Ahora · RC13 build 20020

1. **034 Notificaciones** — implementado local; pendiente Supabase real.
2. **035 Perfil público de club** — implementado local; pendiente Supabase real.
3. **036 Acceso social / edad / seguridad UGC** — implementado local; pendiente Supabase real.
4. **Regresión completa** — obligatoria tras cualquier corrección.
5. **Android físico + actualización encima de versión anterior**.
6. **Freeze MVP**.
7. **AAB / Google Play / deploy web final**.

## Después del freeze

La siguiente etapa podrá convertir la arquitectura validada en una plataforma multiclub con nombre y branding propios. Urban Warriors será un tenant más; no se implementa esa experiencia en RC13.

Capas futuras, deliberadamente fuera de este build:
- Social Community / Comunidad General completa;
- competidor independiente;
- federación;
- marca;
- tienda;
- relaciones/seguidores/contactos;
- mensajería;
- multiclub visible y selector de clubes;
- brackets automáticos y otras funciones avanzadas.

Cada capa futura deberá respetar `PLATFORM_EVOLUTION_RULES.md` y mantener migraciones, RLS, contrato, tests y actualización compatible de la app existente.
