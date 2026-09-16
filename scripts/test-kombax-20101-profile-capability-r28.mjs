import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=path.resolve(fileURLToPath(new URL('..',import.meta.url)));
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const gateway=read('web/js/modules/gateway.js');
const repos=read('web/js/core/repositories.js');
const registry=read('web/js/core/profile-registry.js');
const resolver=read('web/js/core/capability-resolver.js');
const identity=read('web/js/core/identity-context.js');
const index=read('web/index.html');
const sw=read('web/service-worker.js');
const checks=[
 ['R28 registry exists',registry.includes("id:'profesional'")&&registry.includes("id:'espectador'")],
 ['Competidor not professional subtype',registry.includes("{id:'competidor'")&&registry.includes("{id:'profesional'")&&registry.includes('competitor_is_professional_subtype:false')],
 ['Professional specialties controlled',registry.includes("code:'entrenador'")&&registry.includes("code:'representante_manager'")&&registry.includes("code:'medico_sanitario'")&&registry.includes("code:'arbitro_juez'")&&registry.includes("code:'promotor_organizador'")],
 ['Gateway keeps Professional active and Spectator as base identity',gateway.includes("['competidor','marca','federacion','profesional','media']")&&registry.includes("id:'espectador'")&&registry.includes('baseOnly:true')],
 ['Professional birth date captured',gateway.includes("type==='profesional'")&&gateway.includes("name:'fecha_nacimiento'")],
 ['Spectator private age gate copy',gateway.includes('Espectador: alta autónoma 16+')],
 ['Spectator cannot request verification',gateway.includes("p.tipo!=='espectador'")],
 ['R196 profiles source',repos.includes('app_kombax_mis_perfiles_v196')],
 ['R196 mutation source',repos.includes('app_kombax_perfil_mutate_v196')],
 ['Capabilities backend resolver',resolver.includes('app_kombax_profile_capabilities_v196')],
 ['Capabilities cache subject scoped',resolver.includes('const cache=new Map()')&&resolver.includes('cache.delete(key(profileId))')],
 ['Identity change invalidates cache',identity.includes('kombax-identity-changed')&&resolver.includes('kombax-identity-changed')],
 ['R28 cache bust',index.includes('20101r28')&&sw.includes('media-r28')]
];
let ok=0;for(const [name,pass] of checks){if(!pass){console.error('FAIL · '+name);process.exitCode=1;}else{ok++;console.log('PASS · '+name)}}console.log(`R28 ${ok}/${checks.length}`);
