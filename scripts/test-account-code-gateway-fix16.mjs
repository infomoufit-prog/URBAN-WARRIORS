import {PGlite} from '@electric-sql/pglite';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
const db=new PGlite();let n=0;try{
await db.exec(`create table app_mutation_requests(request_id uuid primary key,result jsonb);create function app_kombax_codigo_validar_seguro_v086(text,text,text) returns jsonb language sql as $$select jsonb_build_object('valid',$3='12345','version',1)$$;create function app_mutate_v160_pre_access_codes_060(text,jsonb,uuid) returns jsonb language plpgsql as $$begin insert into public.app_mutation_requests values($3,null);return jsonb_build_object('ok',true,'data',jsonb_build_object('id','fixture'));end$$;`);
await db.exec(readFileSync('scripts/fixtures/account-code-live-fix16.sql','utf8'));
const call=(code='12345')=>db.query("select app_mutate_v160_pre_lifecycle_133('cuenta.registrar',$1,gen_random_uuid()) v",[JSON.stringify({club_slug:'qa','invite_code:':null,invite_code:code})]);
await assert.rejects(()=>call(),/ambiguous/);n++;
await db.exec(readFileSync('supabase/migrations/20261006213057_family_code_registration_result_fix16.sql','utf8'));
await db.exec(readFileSync('supabase/migrations/20261006213119_family_registration_variable_fix16.sql','utf8'));
const out=(await call()).rows[0].v;assert.equal(out.ok,true);n++;assert.equal(out.data.club_access_code.tipo,'alumnos');n++;assert.equal(out.data.club_access_code.version,1);n++;
assert.deepEqual((await db.query('select result from app_mutation_requests')).rows[0].result,out);n++;
assert.equal((await call('wrong')).rows[0].v.ok,false);n++;assert.equal((await db.query('select count(*)::int n from app_mutation_requests')).rows[0].n,1);n++;
await db.exec(readFileSync('supabase/migrations/20261006213119_family_registration_variable_fix16.sql','utf8'));assert.equal((await call()).rows[0].v.ok,true);n++;
console.log('PASS '+n+' account-code gateway checks (real wrapper; isolated downstream stub)');
}finally{await db.close();}
