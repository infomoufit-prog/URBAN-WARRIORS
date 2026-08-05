-- DATOS DE DEMOSTRACIÓN. NO EJECUTAR EN PRODUCCIÓN.
insert into public.clubes(id,nombre,slug,lema,logo_url,color_primario,color_secundario)
values
('11111111-1111-4111-8111-111111111111','Urban Warriors','urban-warriors','Bring the Pain','/assets/urban-warriors-logo.png','#ffffff','#050608'),
('22222222-2222-4222-8222-222222222222','Club Demo Norte','club-demo-norte','Disciplina y comunidad',null,'#f5f5f5','#111827')
on conflict(id) do nothing;

insert into public.config_club(club_id,clave,valor,descripcion) values
('11111111-1111-4111-8111-111111111111','dia_vencimiento','9','Día de vencimiento de cuotas'),
('11111111-1111-4111-8111-111111111111','dia_generacion','1','Día de generación de cuotas')
on conflict do nothing;

insert into public.disciplinas(id,club_id,nombre,descripcion,color,orden) values
('a1111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','Muay Thai','Técnica, acondicionamiento y combate.','#ffffff',1),
('a1111111-1111-4111-8111-111111111112','11111111-1111-4111-8111-111111111111','Kickboxing','Golpeo, coordinación y resistencia.','#d1d5db',2),
('a2222222-2222-4222-8222-222222222221','22222222-2222-4222-8222-222222222222','Muay Thai','Disciplina independiente del Club A.','#ffcc00',1)
on conflict(id) do nothing;

insert into public.grupos(id,club_id,disciplina_id,nombre,monitor_nombre,edad_min,edad_max,plazas) values
('b1111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','a1111111-1111-4111-8111-111111111111','Infantil','Álex',7,13,20),
('b1111111-1111-4111-8111-111111111112','11111111-1111-4111-8111-111111111111','a1111111-1111-4111-8111-111111111111','Adultos tarde','Álex',14,null,24)
on conflict(id) do nothing;

insert into public.horarios_grupo(club_id,grupo_id,dia_semana,hora_inicio,hora_fin) values
('11111111-1111-4111-8111-111111111111','b1111111-1111-4111-8111-111111111111',2,'17:00','18:00'),
('11111111-1111-4111-8111-111111111111','b1111111-1111-4111-8111-111111111111',4,'17:00','18:00'),
('11111111-1111-4111-8111-111111111111','b1111111-1111-4111-8111-111111111112',2,'18:30','20:00')
on conflict do nothing;

insert into public.tarifas(id,club_id,nombre,descripcion,importe,periodicidad,orden) values
('c1111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','Infantil','Plan mensual infantil',35,'mensual',1),
('c1111111-1111-4111-8111-111111111112','11111111-1111-4111-8111-111111111111','Adultos','Plan mensual adultos',45,'mensual',2)
on conflict(id) do nothing;
