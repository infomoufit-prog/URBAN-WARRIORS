import {PGlite} from '@electric-sql/pglite';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
const db=new PGlite();let n=0;const ok=(label,v)=>{assert.ok(v,label);n++};const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
try{
await db.exec(`create table public.clubes(id uuid primary key,activo boolean);
create table public.perfiles_kombax_directos(id uuid primary key default gen_random_uuid(),tipo text,origen_identidad_social_id uuid,estado text default 'borrador',verificacion_estado text default 'no_iniciada',workflow_estado text default 'draft',social_activo boolean default false,slug text,nombre_publico text,descripcion text check(length(descripcion)<=1600),avatar_path text,banner_path text);
create table public.kombax_perfil_persona_privada_v196(perfil_directo_id uuid,fecha_nacimiento date);
create function public.app_kombax_profile_age_v196(date) returns int language sql as $$select extract(year from age(current_date,$1))::int$$;
create function public.app_kombax_subscription_paid_v102(text,uuid) returns boolean language sql as $$select false$$;
create function public.app_kombax_social_switch_competitor_v072(uuid) returns void language sql as $$select$$;
create table public.kombax_social_perfiles(sujeto_tipo text,perfil_directo_id uuid,club_id uuid,slug text,nombre_publico text,bio text check(length(bio)<=800),avatar_path text,banner_path text,avatar_url text,banner_url text,verificado boolean,visible boolean,publicar_habilitado boolean,contacto_habilitado boolean,estado text,actualizado_en timestamptz);
create unique index social_direct on public.kombax_social_perfiles(perfil_directo_id) where sujeto_tipo='perfil_directo';
create table public.perfiles_club_publicos(club_id uuid,slug text,nombre_publico text,descripcion text,logo_url text,portada_url text,moderacion_oculta boolean default false);`);
await db.exec(read('supabase/tests/fixtures-social-sync-before-fix11.sql'));
await db.exec(`create trigger sync_direct after insert or update on public.perfiles_kombax_directos for each row execute function public.app_kombax_social_sync_directo_v041();create trigger sync_club after insert or update on public.perfiles_club_publicos for each row execute function public.app_kombax_social_sync_club_public_v051();`);
const create=t=>db.query("insert into public.perfiles_kombax_directos(tipo,slug,nombre_publico,descripcion) values($1,$1,$1,$2) returning id",[t,'a'.repeat(1600)]);
await assert.rejects(create('marca'),/check constraint/);n++;
await db.exec(read('supabase/migrations/20261004200243_kombax_profile_social_bio_limit_r119.sql'));
for(const t of ['espectador','competidor','profesional','media','marca','federacion']){
 const id=(await create(t)).rows[0].id;
 const row=(await db.query('select length(d.descripcion) full_length,length(s.bio) bio_length,s.publicar_habilitado from public.perfiles_kombax_directos d join public.kombax_social_perfiles s on s.perfil_directo_id=d.id where d.id=$1',[id])).rows[0];
 ok(t+' full description retained',row.full_length===1600);ok(t+' Social preview fits',row.bio_length===800);ok(t+' verification gates preserved',row.publicar_habilitado===false);
}
await db.exec(`insert into public.clubes values('00000000-0000-4000-8000-000000000010',true);insert into public.kombax_social_perfiles(sujeto_tipo,club_id) values('club','00000000-0000-4000-8000-000000000010');insert into public.perfiles_club_publicos(club_id,slug,nombre_publico,descripcion) values('00000000-0000-4000-8000-000000000010','club','Club',repeat('a',1200));`);
ok('Club complete introduction retained',(await db.query('select length(descripcion) n from perfiles_club_publicos')).rows[0].n===1200);
ok('Club Social preview fits',(await db.query("select length(bio) n from kombax_social_perfiles where sujeto_tipo='club'")).rows[0].n===800);
console.log('PASS '+n+'/'+n+' profile Social bio regression');
}finally{await db.close();}
