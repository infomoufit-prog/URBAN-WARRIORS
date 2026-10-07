import {PGlite} from '@electric-sql/pglite';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const db=new PGlite();let n=0;const ok=(v)=>{assert.ok(v);n++;};
try{
await db.exec(`create role anon;create role authenticated;create schema auth;create schema kombax_payments;create schema kombax_compliance;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('qa.uid',true),'')::uuid$$;
create table public.kombax_showcase_elementos(id uuid primary key,marca_id uuid);
create table kombax_compliance.product_profiles(product_id uuid,compliance_documents jsonb,manufacturer_in_eu boolean);
create table kombax_compliance.product_category_rules(category_code text,label text,policy_status text,manufacturer_required boolean,eu_responsible_person_when_non_eu boolean,ce_requirement text,warnings_required boolean,documentation_required boolean);
create function kombax_payments.can_manage_provider(uid uuid,provider uuid) returns boolean language sql as $$select uid=provider$$;
create function kombax_compliance.product_compliance_ready_r630(id uuid) returns boolean language sql as $$select false$$;
insert into public.kombax_showcase_elementos values('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000001');
insert into kombax_compliance.product_profiles values('00000000-0000-4000-8000-000000000010','[{"private_path":"secret.pdf"}]',true);
insert into kombax_compliance.product_category_rules values('general_goods','General','allowed',true,true,'conditional',false,false);`);
for(const f of ['20261006214336_product_compliance_rules_ui_fix16.sql','20261006214428_product_compliance_editor_fix16.sql'])await db.exec(await readFile(new URL('../supabase/migrations/'+f,import.meta.url),'utf8'));
for(const f of ['app_showcase_product_editor_fix16(uuid)','app_showcase_product_rules_fix16()']){ok((await db.query(`select has_function_privilege('authenticated','public.${f}','execute') x`)).rows[0].x);ok(!(await db.query(`select has_function_privilege('anon','public.${f}','execute') x`)).rows[0].x);}
await assert.rejects(()=>db.query('select public.app_showcase_product_rules_fix16()'),/AUTH_REQUIRED/);n++;
await db.query(`select set_config('qa.uid','00000000-0000-4000-8000-000000000002',false)`);
await assert.rejects(()=>db.query(`select public.app_showcase_product_editor_fix16('00000000-0000-4000-8000-000000000010')`),/SHOWCASE_MANAGEMENT_REQUIRED/);n++;
await db.query(`select set_config('qa.uid','00000000-0000-4000-8000-000000000001',false)`);
const x=(await db.query(`select public.app_showcase_product_editor_fix16('00000000-0000-4000-8000-000000000010') x`)).rows[0].x;
ok(x.product.manufacturer_in_eu===true);ok(x.product.compliance_documents[0].private_path==='secret.pdf');ok(x.commerce_ready===false);
await assert.rejects(()=>db.query(`select public.app_showcase_product_editor_fix16('00000000-0000-4000-8000-000000000099')`),/SHOWCASE_MANAGEMENT_REQUIRED/);n++;
ok((await db.query('select public.app_showcase_product_rules_fix16() x')).rows[0].x[0].category_code==='general_goods');
console.log(`PASS ${n} product compliance editor permission cases`);
}finally{await db.close();}
