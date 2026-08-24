import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const read=path=>readFile(new URL(`../${path}`,import.meta.url),'utf8');
const [sql,showcase,publicProfile,config,gradle,index,worker]=await Promise.all([
  read('supabase/migrations/113_kombax_showcase_all_profile_types_20068.sql'),
  read('web/js/modules/showcase.js'),read('web/js/modules/public-profile.js'),read('web/config.js'),
  read('android/app/build.gradle'),read('web/index.html'),read('web/service-worker.js')
]);

for(const type of ['marca','club','federacion','competidor']){
  assert.ok(sql.includes(`'${type}'`),`backend incluye ${type}`);
  assert.ok(showcase.includes(type),`frontend etiqueta ${type}`);
}
assert.match(sql,/showcase\.publish/);
assert.match(sql,/app_kombax_showcase_ensure_direct_v113/);
assert.match(sql,/app_kombax_perfil_servicio_activo_v071/);
assert.match(sql,/app_kombax_puede_gestionar_perfil_v070/);
assert.match(sql,/app_kombax_plan_limite_v071/);
assert.match(sql,/app_kombax_perfil_publico_v094/);
assert.ok(publicProfile.includes("['club','marca','federacion','competidor']"));
assert.ok(!showcase.includes("x.sujeto_tipo==='club'?'Club':'Marca'"),'la UI no degrada Federación/Competidor a Marca');
const currentBuild=Number(config.match(/build:\s*(\d+)/)?.[1]);
assert.ok(currentBuild>=20068);
assert.equal(Number(gradle.match(/versionCode\s+(\d+)/)?.[1]),currentBuild);
assert.ok(index.includes(`v=${currentBuild}`));
assert.ok(worker.includes(`rc13-${currentBuild}`));

console.log('KOMBAX 20068 Showcase perfiles: PASS');
