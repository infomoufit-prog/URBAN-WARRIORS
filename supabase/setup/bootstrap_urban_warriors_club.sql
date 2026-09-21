-- ============================================================================
-- URBAN WARRIORS · DATOS INICIALES DEL CLUB
-- Aplicar después de las migraciones 001-005.
-- No crea usuarios ni datos de demostración.
-- ============================================================================

insert into public.clubes (
  id, nombre, slug, lema, color_primario, color_secundario,
  idioma, zona_horaria, activo
) values (
  '11111111-1111-4111-8111-111111111111',
  'Urban Warriors',
  'urban-warriors',
  'Bring the Pain',
  '#ffffff',
  '#050608',
  'es',
  'Europe/Madrid',
  true
)
on conflict (id) do update set
  nombre = excluded.nombre,
  slug = excluded.slug,
  lema = excluded.lema,
  color_primario = excluded.color_primario,
  color_secundario = excluded.color_secundario,
  idioma = excluded.idioma,
  zona_horaria = excluded.zona_horaria,
  activo = excluded.activo,
  actualizado_en = now();

insert into public.config_club (club_id, clave, valor, descripcion, editable_por)
values
  ('11111111-1111-4111-8111-111111111111', 'nombre_club', to_jsonb('Urban Warriors'::text), 'Nombre visible en la aplicación', 'direccion'),
  ('11111111-1111-4111-8111-111111111111', 'dia_generacion', '1'::jsonb, 'Día mensual de generación de cuotas', 'economia'),
  ('11111111-1111-4111-8111-111111111111', 'dia_vencimiento', '15'::jsonb, 'Día de vencimiento de la mensualidad', 'economia'),
  ('11111111-1111-4111-8111-111111111111', 'telefono_contacto', 'null'::jsonb, 'Teléfono de contacto', 'secretaria'),
  ('11111111-1111-4111-8111-111111111111', 'bizum_numero', 'null'::jsonb, 'Número informativo para Bizum', 'economia'),
  ('11111111-1111-4111-8111-111111111111', 'texto_privacidad', to_jsonb(''::text), 'Política de privacidad', 'secretaria'),
  ('11111111-1111-4111-8111-111111111111', 'texto_imagen', to_jsonb(''::text), 'Cláusula de derechos de imagen', 'secretaria')
on conflict (club_id, clave) do update set
  valor = excluded.valor,
  descripcion = excluded.descripcion,
  editable_por = excluded.editable_por,
  actualizado_en = now();

insert into public.configuracion_avisos_cuota (
  club_id, activo, dias_aviso, hora_envio, zona_horaria,
  canal_app, canal_push, canal_email, agrupar_por_familia,
  marcar_vencida_dia
) values (
  '11111111-1111-4111-8111-111111111111',
  true,
  array[1,4,8,11,14]::smallint[],
  '10:00',
  'Europe/Madrid',
  true,
  false,
  false,
  true,
  15
)
on conflict (club_id) do update set
  activo = excluded.activo,
  dias_aviso = excluded.dias_aviso,
  hora_envio = excluded.hora_envio,
  zona_horaria = excluded.zona_horaria,
  canal_app = excluded.canal_app,
  canal_push = excluded.canal_push,
  canal_email = excluded.canal_email,
  agrupar_por_familia = excluded.agrupar_por_familia,
  marcar_vencida_dia = excluded.marcar_vencida_dia,
  actualizado_en = now();

select id, nombre, slug, activo from public.clubes where slug = 'urban-warriors';
select * from public.configuracion_avisos_cuota where club_id = '11111111-1111-4111-8111-111111111111';
