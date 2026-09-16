# Backend state · R60 Pilot Final

## Supabase live

Project ref: `poggsobhtutbuagjiydc`

### Migraciones finales

- `253_kombax_pilot_management_assist_r60.sql`
  - autoriza Assist de gestión para Club/Federación/Marca;
  - mantiene Migrations en Club/Federación;
  - añade snapshot de gestión compacto y read-only;
  - expone límites por plan al frontend.

- `254_kombax_support_guided_management_split_r60.sql`
  - conserva el chat guiado de Soporte;
  - crea/asegura separación `MANAGEMENT` / `MIGRATION` / Soporte;
  - impide autoactivación del chat formal por el cliente;
  - expone estado seguro del chat guiado;
  - conserva posibilidad de revisión humana.

### Edge Function

`kombax-assist-r38` · live ACTIVE v7.

La función valida el bearer contra Supabase Auth dentro de su cuerpo, por lo que conserva `verify_jwt=false` a nivel gateway, igual que la rama anterior del runtime. Rutea instrucciones distintas para gestión, Migrations y Soporte guiado.

### Modelo

La política actual usa `gpt-5.6-luna` como modelo por defecto y `gpt-5.6-terra` como escalado configurado en la política interna. El frontend no expone nombres de modelo ni tokens al usuario.

### Separación funcional

- MANAGEMENT: gestión asistida, directo, cuota mensual, solo lectura.
- MIGRATION: migración especializada, directo para Club/Federación, cuota propia.
- Soporte: ticket formal; chat guiado solo con sesión activa de Soporte; revisión humana disponible.
