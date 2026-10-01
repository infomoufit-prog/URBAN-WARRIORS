import fs from 'node:fs';
import assert from 'node:assert/strict';

const sql=fs.readFileSync(new URL('../supabase/migrations/299_kombax_free_public_identity_capabilities_r112.sql',import.meta.url),'utf8');
const r111=fs.readFileSync(new URL('../supabase/migrations/298_kombax_account_identity_guard_table_scope_fix_r111.sql',import.meta.url),'utf8');
let pass=0;
const test=(name,fn)=>{try{fn();pass++;console.log('PASS',name);}catch(e){console.error('FAIL',name,e.message);process.exitCode=1;}};

test('R111 source recovered',()=>assert.match(r111,/tg_table_name='kombax_solicitudes_alta'/));
test('verified direct identity public without service dependency',()=>{
  assert.match(sql,/publico=\(v_verified and v_type in \('competidor','marca','federacion','profesional','media'\)\)/);
  const reconcile=sql.match(/create or replace function public\.app_kombax_reconcile_entitlements_v071[\s\S]*?end \$\$;/)?.[0]||'';
  assert.ok(!/publico=.*v_service/.test(reconcile));
});
test('paid entitlements still require verified plus active service',()=>assert.match(sql,/if v_verified and coalesce\(v_service,false\) and v_plan is not null then/));
test('direct social supports competitor brand federation professional media',()=>assert.match(sql,/new\.tipo not in \('competidor','marca','federacion','profesional','media'\)/));
test('social visibility no longer requires service',()=>{
  const sync=sql.match(/create or replace function public\.app_kombax_social_sync_directo_v041[\s\S]*?end \$\$;/)?.[0]||'';
  assert.ok(!sync.includes('app_kombax_perfil_servicio_activo_v071'));
});
test('brand federation badge still requires paid evidence',()=>assert.match(sql,/app_kombax_subscription_paid_v102\('perfil_directo',new\.id\)/));
test('competitor continuity no subscription requirement',()=>{
  const sw=sql.match(/create or replace function public\.app_kombax_social_switch_competitor_v072[\s\S]*?end \$\$;/)?.[0]||'';
  assert.ok(!sw.includes('app_kombax_perfil_servicio_activo_v071'));
  assert.match(sw,/origen_identidad_social_id/);
});
test('album public read only needs verified public identity',()=>{
  const album=sql.match(/create or replace function public\.app_kombax_album_v072[\s\S]*?end \$\$;/)?.[0]||'';
  assert.ok(!album.includes('app_kombax_perfil_servicio_activo_v071'));
  assert.match(album,/v_public and v_official/);
});
test('media add no longer requires service but still requires verification',()=>{
  const media=sql.match(/create or replace function public\.app_kombax_media_mutate_v072[\s\S]*?end \$\$;/)?.[0]||'';
  assert.ok(!media.includes('app_kombax_perfil_servicio_activo_v071'));
  assert.match(media,/KOMBAX_PROFILE_VERIFIED_REQUIRED/);
});
test('showcase plan gates not modified by R112',()=>assert.ok(!sql.includes('app_kombax_showcase_ensure_direct_v113')));

console.log(`R112 free identity visibility QA: ${pass}/10`);
if(process.exitCode) process.exit(process.exitCode);
