import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';
import {readFileSync} from 'node:fs';
import {identityChoices,resolveIdentity,publicationIdentity,combineIdentityRecords} from '../web/js/core/social-identity-resolution.js';
let n=0;const ok=(name,fn)=>{fn();n++;};const u=x=>`00000000-0000-4000-8000-${String(x).padStart(12,'0')}`;
const person={id:u(1),canonical_social_id:u(1),is_personal:true,personal_aliases:[u(1),u(2)],sujeto_tipo:'miembro',publication_enabled:false};
const fighter={...person,id:u(2),perfil_tipo:'competidor',publication_enabled:true};
const brand={id:u(3),sujeto_tipo:'perfil_directo',perfil_tipo:'marca',publication_enabled:false};
const club={id:u(4),club_id:u(20),sujeto_tipo:'club',publication_enabled:true};
const rows=[person,fighter,brand,club];
ok('personal facets grouped; entities retained',()=>assert.equal(identityChoices(rows).length,3));
ok('selected facet retained',()=>assert.equal(identityChoices(rows,fighter.id)[0].id,fighter.id));
ok('member defaults to person',()=>assert.equal(resolveIdentity([club,brand,person],{clubId:u(20),role:'alumno'}).id,person.id));
ok('selected coordinator defaults to club',()=>assert.equal(resolveIdentity(rows,{clubId:u(20),role:'coordinacion'}).id,club.id));
ok('stored brand preserved',()=>assert.equal(resolveIdentity(rows,{storedId:brand.id}).id,brand.id));
ok('blocked brand never replaced by club',()=>assert.equal(publicationIdentity(rows,brand.id),null));
ok('unknown actor never replaced',()=>assert.equal(publicationIdentity(rows,u(999)),null));
ok('verified personal facet enables same person',()=>assert.equal(publicationIdentity(rows,person.id).id,fighter.id));
ok('spectator cannot publish',()=>assert.equal(publicationIdentity([{...fighter,perfil_tipo:'espectador'}],fighter.id),null));
ok('empty list safe',()=>assert.equal(resolveIdentity([]),null));
ok('history deduplicates without changing IDs',()=>assert.deepEqual(combineIdentityRecords([{id:'a',creado_en:'2026-01-01'},{id:'b',creado_en:'2026-02-01'},{id:'a'}],1).map(p=>p.id),['b']));
const db=new PGlite();
await db.exec(`create role anon;create role authenticated;create schema auth;create schema private;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table public.identidades_sociales(id uuid,perfil_id uuid,club_origen_id uuid,estado text);
create table public.perfiles_kombax_directos(id uuid,perfil_id uuid,tipo text);
create table public.clubes(id uuid,nombre text);
create table public.kombax_social_perfiles(id uuid,sujeto_tipo text,identidad_social_id uuid,perfil_directo_id uuid,club_id uuid,nombre_publico text,slug text,visible boolean,estado text,verificado boolean,creado_en timestamptz,owner_id uuid,publish boolean);
create table public.qa_blocked(id uuid);
create function public.app_kombax_social_tipo_v051(p uuid) returns text language sql as $$select case when sp.sujeto_tipo='perfil_directo' then d.tipo else sp.sujeto_tipo end from kombax_social_perfiles sp left join perfiles_kombax_directos d on d.id=sp.perfil_directo_id where sp.id=p$$;
create function public.app_kombax_social_puede_actuar_v051(p uuid) returns boolean language sql as $$select coalesce((select publish and owner_id=auth.uid() and estado='activo' and visible from kombax_social_perfiles where id=p),false)$$;
create function public.app_kombax_social_puede_gestionar_perfil_publico_r117(p uuid) returns boolean language sql as $$select coalesce((select owner_id=auth.uid() and estado in ('activo','limitado') from kombax_social_perfiles where id=p),false)$$;
create function public.app_kombax_social_network_actor_allowed_v255(p uuid) returns boolean language sql as $$select coalesce((select owner_id=auth.uid() and visible and estado='activo' from kombax_social_perfiles where id=p),false)$$;
create function private.kombax_workspace_club_access_v147(p uuid) returns boolean language sql as $$select p='${u(20)}' and auth.uid() in ('${u(30)}','${u(31)}')$$;
create function public.app_kombax_support_club_v140(p uuid) returns boolean language sql as $$select false$$;
create function public.app_kombax_social_contactable_v041(p uuid) returns boolean language sql as $$select true$$;
create function public.app_kombax_social_avatar_url_v063(p uuid) returns text language sql as $$select ''::text$$;
create function public.app_kombax_social_avatar_path_v058(p uuid) returns text language sql as $$select ''::text$$;
create function public.app_kombax_social_banner_url_v063(p uuid) returns text language sql as $$select ''::text$$;
create function public.app_kombax_social_banner_path_v058(p uuid) returns text language sql as $$select ''::text$$;
create function public.app_kombax_perfil_publico_v094(p uuid) returns jsonb language sql as $$select to_jsonb(sp) from kombax_social_perfiles sp where id=p and visible and estado='activo' and not exists(select 1 from qa_blocked where id=p)$$;
create function public.app_kombax_social_directorio_v072(q text,l integer) returns setof kombax_social_perfiles language sql as $$select * from kombax_social_perfiles where visible and estado='activo' and nombre_publico ilike '%'||q||'%' order by id limit l$$;
create function public.app_kombax_social_mis_perfiles_r117(p uuid) returns table(id uuid,sujeto_tipo text,nombre_publico text,slug text,avatar_url text,avatar_path text,banner_url text,banner_path text,verificado boolean,contacto_habilitado boolean,perfil_directo_id uuid,perfil_tipo text,club_id uuid,club_nombre text,identity_label text,publication_enabled boolean,network_enabled boolean,album_enabled boolean) language sql as $$select null::uuid,null::text,null::text,null::text,null::text,null::text,null::text,null::text,false,false,null::uuid,null::text,null::uuid,null::text,null::text,false,false,false where false$$;
insert into clubes values('${u(20)}','Club');
insert into identidades_sociales values('${u(40)}','${u(30)}','${u(20)}','activa'),('${u(41)}','${u(31)}','${u(20)}','activa');
insert into perfiles_kombax_directos values('${u(50)}','${u(30)}','competidor'),('${u(51)}','${u(30)}','profesional'),('${u(52)}','${u(30)}','marca'),('${u(53)}','${u(30)}','federacion'),('${u(54)}','${u(30)}','media'),('${u(55)}','${u(30)}','espectador');
insert into kombax_social_perfiles values
('${u(1)}','miembro','${u(40)}',null,null,'Person','person',true,'activo',false,'2026-01-01','${u(30)}',false),
('${u(2)}','perfil_directo',null,'${u(50)}',null,'Fighter','fighter',true,'activo',true,'2026-01-02','${u(30)}',true),
('${u(3)}','perfil_directo',null,'${u(51)}',null,'Professional','professional',true,'activo',false,'2026-01-03','${u(30)}',false),
('${u(4)}','perfil_directo',null,'${u(52)}',null,'Brand','brand',true,'activo',false,'2026-01-04','${u(30)}',false),
('${u(5)}','perfil_directo',null,'${u(53)}',null,'Federation','federation',true,'activo',true,'2026-01-05','${u(30)}',true),
('${u(6)}','perfil_directo',null,'${u(54)}',null,'Media','media',true,'activo',true,'2026-01-06','${u(30)}',true),
('${u(7)}','miembro','${u(41)}',null,null,'Other person','other',true,'activo',false,'2026-01-07','${u(31)}',false),
('${u(8)}','club',null,null,'${u(20)}','Club','club',true,'activo',true,'2026-01-08','${u(30)}',true),
('${u(9)}','perfil_directo',null,'${u(55)}',null,'Spectator','spectator',true,'activo',false,'2026-01-09','${u(30)}',false);`);
await db.exec(`do $$declare f record;begin for f in select p.oid::regprocedure::text signature from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname='public' loop execute 'alter function '||f.signature||' set search_path=public,auth';end loop;end $$;`);
await db.exec(readFileSync('supabase/migrations/20261014221616_social_identity_resolution_r271.sql','utf8'));
const as=async id=>db.query("select set_config('request.jwt.claim.sub',$1,false)",[id||'']);
const call=async(sql,args=[])=>(await db.query(sql,args)).rows[0].v;
await assert.rejects(call('select app_kombax_social_identity_catalog_r271() v'),/AUTH_REQUIRED/);n++;
await as(u(30));
const catalog=await call('select app_kombax_social_identity_catalog_r271() v');
ok('pending brand listed',()=>assert.ok(catalog.find(p=>p.id===u(4))&&!catalog.find(p=>p.id===u(4)).publication_enabled));
ok('spectator interaction without publication',()=>assert.ok(catalog.find(p=>p.id===u(9)).network_enabled&&!catalog.find(p=>p.id===u(9)).publication_enabled));
ok('personal group without organization collision',()=>assert.equal(identityChoices(catalog).length,5));
ok('other person absent from management',()=>assert.ok(!catalog.find(p=>p.id===u(7))));
const bundle=await call('select app_kombax_social_identity_bundle_r271($1) v',[u(2)]);
ok('old personal link resolves existing canonical',()=>assert.equal(bundle.canonical_social_id,u(1)));
ok('all personal variants retained',()=>assert.equal(bundle.variants.length,4));
for(const id of [4,5,6,8]){const b=await call('select app_kombax_social_identity_bundle_r271($1) v',[u(id)]);ok('entity '+id+' not merged',()=>assert.equal(b.variants.length,1));}
const workspace=await call('select app_kombax_social_identity_catalog_r271($1,true) v',[u(20)]);
ok('club workspace preserves member without publishing',()=>assert.ok(workspace.find(p=>p.id===u(1))));
ok('other organizations do not enter club workspace',()=>assert.ok(!workspace.find(p=>p.id===u(4))));
const directory=await call("select app_kombax_social_directory_r271('',50) v");
ok('directory one card per person and entity',()=>assert.equal(directory.length,6));
await db.exec(`insert into qa_blocked values('${u(1)}')`);
const blocked=await call('select app_kombax_social_identity_bundle_r271($1) v',[u(2)]);
ok('blocked variant never exposed',()=>assert.ok(!blocked.personal_aliases.includes(u(1))));
ok('unreadable canonical never exposed',()=>assert.equal(blocked.canonical_social_id,u(2)));
await as(u(31));
const canClub=await call('select private.kombax_workspace_actor_allowed_v147($1,$2) v',[u(20),u(8)]);
ok('member cannot represent club',()=>assert.equal(canClub,false));
await as(u(999));await assert.rejects(call('select app_kombax_social_identity_catalog_r271($1,true) v',[u(20)]),/CLUB_ACCESS_REQUIRED/);n++;
const empty=await call('select app_kombax_social_identity_catalog_r271() v');ok('unrelated account has no managed actors',()=>assert.equal(empty.length,0));
for(const name of ['private.kombax_social_person_owner_r271(uuid)','private.kombax_social_identity_meta_r271(uuid)'])for(const role of ['anon','authenticated']){
 const grant=await call('select has_function_privilege($1,$2,\'execute\') v',[role,name]);ok('private helper '+name+' '+role,()=>assert.equal(grant,false));
}
for(const name of ['public.app_kombax_social_identity_catalog_r271(uuid,boolean)','public.app_kombax_social_identity_bundle_r271(uuid)','public.app_kombax_social_directory_r271(text,integer)']){
 const anon=await call('select has_function_privilege(\'anon\',$1,\'execute\') v',[name]);ok('anonymous excluded '+name,()=>assert.equal(anon,false));
}
await db.close();console.log(`PASS ${n} R271 identity selection, grouping, permissions and SQL checks; no external writes`);
