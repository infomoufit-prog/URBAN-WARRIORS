-- SOLO ENTORNO LOCAL / QA. NO EJECUTAR EN PRODUCCIÓN.
-- Crea cinco tenants ficticios; Urban Warriors ya es el sexto perfil del directorio.
begin;

insert into public.clubes(id,nombre,slug,lema,theme_id,branding_version,activo) values
('d0000001-0000-4000-8000-000000000001','Northside Boxing Lab','northside-boxing-lab','Precision under pressure','performance-pro',1,true),
('d0000002-0000-4000-8000-000000000002','Dojo Sakura','dojo-sakura','Disciplina y tradición','dojo-heritage',1,true),
('d0000003-0000-4000-8000-000000000003','Titan MMA Center','titan-mma-center','Train all ranges','combat-dark',1,true),
('d0000004-0000-4000-8000-000000000004','Costa Combat Academy','costa-combat-academy','Performance by the sea','performance-pro',1,true),
('d0000005-0000-4000-8000-000000000005','Fénix Kickboxing Club','fenix-kickboxing-club','Rise every round','champion-gold',1,true)
on conflict(id) do update set nombre=excluded.nombre,lema=excluded.lema,theme_id=excluded.theme_id,activo=true;

insert into public.perfiles_club_publicos(club_id,slug,nombre_publico,lema,ciudad,provincia,pais,visible) values
('d0000001-0000-4000-8000-000000000001','northside-boxing-lab','Northside Boxing Lab','Precision under pressure','Bilbao','Bizkaia','España',true),
('d0000002-0000-4000-8000-000000000002','dojo-sakura','Dojo Sakura','Disciplina y tradición','Valencia','Valencia','España',true),
('d0000003-0000-4000-8000-000000000003','titan-mma-center','Titan MMA Center','Train all ranges','Madrid','Madrid','España',true),
('d0000004-0000-4000-8000-000000000004','costa-combat-academy','Costa Combat Academy','Performance by the sea','Málaga','Málaga','España',true),
('d0000005-0000-4000-8000-000000000005','fenix-kickboxing-club','Fénix Kickboxing Club','Rise every round','Zaragoza','Zaragoza','España',true)
on conflict(club_id) do update set nombre_publico=excluded.nombre_publico,lema=excluded.lema,ciudad=excluded.ciudad,provincia=excluded.provincia,visible=true;

insert into public.disciplinas(club_id,nombre,descripcion,activa,orden) values
('d0000001-0000-4000-8000-000000000001','Boxeo','Fixture QA',true,1),
('d0000002-0000-4000-8000-000000000002','Karate','Fixture QA',true,1),('d0000002-0000-4000-8000-000000000002','Judo','Fixture QA',true,2),
('d0000003-0000-4000-8000-000000000003','MMA','Fixture QA',true,1),('d0000003-0000-4000-8000-000000000003','Grappling','Fixture QA',true,2),
('d0000004-0000-4000-8000-000000000004','Kickboxing','Fixture QA',true,1),('d0000004-0000-4000-8000-000000000004','Brazilian Jiu-Jitsu','Fixture QA',true,2),
('d0000005-0000-4000-8000-000000000005','Kickboxing','Fixture QA',true,1),('d0000005-0000-4000-8000-000000000005','K-1','Fixture QA',true,2)
on conflict(club_id,nombre) do update set activa=true,descripcion='Fixture QA';

commit;
